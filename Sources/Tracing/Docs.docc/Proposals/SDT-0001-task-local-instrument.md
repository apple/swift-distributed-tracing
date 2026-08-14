# SDT-0001: task-local instrument

A ``withTracer(_:_:)`` free function that binds a ``Tracer`` to the current task. It takes priority over the
process-wide ``InstrumentationSystem/bootstrap(_:)`` for the scope, then falls back to it.

## Overview

- Proposal: SDT-0001
- Author(s): [Vladimir Kukushkin](https://github.com/kukushechkin)
- Status: **In Review**
- Issue: [apple/swift-distributed-tracing#168](https://github.com/apple/swift-distributed-tracing/issues/168)
- Implementation: on the `SDT-0001-task-local-instrument-implementation` branch

### Introduction

This proposal adds the ``withTracer(_:_:)`` free function. It runs a closure with a chosen ``Tracer`` active
for the current task and any child tasks it spawns. Unlike ``InstrumentationSystem/bootstrap(_:)``, which is
set once per process, ``withTracer(_:_:)`` can bind a different tracer per region of work, for example per test.

### Motivation

``InstrumentationSystem/bootstrap(_:)`` installs an instrument **once** per process. From then on, every
`withSpan` / `startSpan` call and every read of ``InstrumentationSystem/instrument`` resolves through that one
instrument. This fits "one tracer for the whole application." Per-test tracers are hard, though. A second
`bootstrap` call crashes, so parallel tests can't each install their own.

### Proposed solution

``withTracer(_:_:)`` runs a closure with a tracer active for the current task:

```swift
// Parallel-safe unit test. The binding is task-local, so concurrent tests don't interfere.
@Test func spansAreCaptured() async {
    let tracer = InMemoryTracer()
    await withTracer(tracer) {
        await withSpan("op") { _ in }   // emits into `tracer`
    }
    #expect(tracer.finishedSpans.count == 1)
}
```

Inside the closure, and in any child tasks it spawns, `tracer` is the active instrument. Span creation
(``InstrumentationSystem/tracer``, `withSpan` / `startSpan`) and propagation (`inject` / `extract`) give it
priority over whatever ``InstrumentationSystem/bootstrap(_:)`` set, because a ``Tracer`` is an ``Instrument``.
Outside the closure, or in tasks that don't inherit the binding, resolution falls back to the bootstrapped
instrument. Nesting ``withTracer(_:_:)`` overrides `tracer` for the inner scope only.

``withTracer(_:_:)`` only accepts a ``Tracer``, not an arbitrary ``Instrument``. `MultiplexInstrument` is not
a `Tracer` either, so while several tools can still be installed together at
``InstrumentationSystem/bootstrap(_:)`` for the whole process, there is no supported way to combine them
within one task-local scope, see Future directions.

### Detailed design

````swift
/// Makes `tracer` the active instrument for the current task and the child tasks it spawns, for the
/// duration of `operation`.
///
/// ``InstrumentationSystem/instrument``, ``InstrumentationSystem/tracer``, `withSpan` / `startSpan`, and
/// propagation (`inject` / `extract`) all favor `tracer` over whatever ``InstrumentationSystem/bootstrap(_:)``
/// set. An unstructured `Task { }` inherits the binding. `Task.detached` does not. Nesting
/// `withTracer(_:_:)` overrides `tracer` for the inner scope only.
///
/// ```swift
/// // Parallel-safe. The binding is task-local, so concurrent tests don't interfere.
/// @Test func spansAreCaptured() async {
///     let tracer = InMemoryTracer()
///     await withTracer(tracer) {
///         await withSpan("op") { _ in }   // emits into `tracer`
///     }
///     #expect(tracer.finishedSpans.count == 1)
/// }
/// ```
///
/// A ``Tracer`` is also an ``Instrument``, so this replaces propagation too, not just span creation. To keep
/// several tools active at once, install a ``MultiplexInstrument`` at ``InstrumentationSystem/bootstrap(_:)``.
///
/// - Parameters:
///   - tracer: The tracer to make active for the duration of `operation`.
///   - operation: The closure to run with `tracer` active.
/// - Returns: The value returned by the closure.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public func withTracer<Result, Failure: Error>(
    _ tracer: any Tracer,
    _ operation: () throws(Failure) -> Result
) throws(Failure) -> Result

#if compiler(>=6.2)
/// Makes `tracer` the active instrument for the current task and the child tasks it spawns, for the
/// duration of `operation`. See the synchronous `withTracer(_:_:)` for the full discussion of replace
/// semantics and the bootstrap fallback.
///
/// - Parameters:
///   - tracer: The tracer to make active for the duration of `operation`.
///   - operation: The async closure to run with `tracer` active.
/// - Returns: The value returned by the closure.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public nonisolated(nonsending) func withTracer<Result, Failure: Error>(
    _ tracer: any Tracer,
    _ operation: nonisolated(nonsending) () async throws(Failure) -> Result
) async throws(Failure) -> Result
#else
/// Makes `tracer` the active instrument for the current task and the child tasks it spawns, for the
/// duration of `operation`. See the synchronous `withTracer(_:_:)` for the full discussion of replace
/// semantics and the bootstrap fallback.
///
/// - Parameters:
///   - tracer: The tracer to make active for the duration of `operation`.
///   - operation: The async closure to run with `tracer` active.
/// - Returns: The value returned by the closure.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public func withTracer<Result, Failure: Error>(
    _ tracer: any Tracer,
    isolation: isolated (any Actor)? = #isolation,
    _ operation: () async throws(Failure) -> Result
) async throws(Failure) -> Result
#endif
````

The scope is backed by an `@TaskLocal` on ``InstrumentationSystem`` typed `(any Instrument)?`. There is no
wrapper instrument, and nothing is installed on first use.

### API stability

- Purely additive: a new free function and an internal task-local. Existing signatures are unchanged.
- Applications that never call ``withTracer(_:_:)`` see no behavioral change. Instrument lookup now checks a
  task-local before falling back to the bootstrapped instrument.
- That task-local read happens on every lookup, including the per-span `withSpan` / `startSpan` path. The
  added cost is negligible next to the work a real tracer already does per span.

### Future directions

- **Combining several tools in one scope.** ``withTracer(_:_:)`` only takes one `Tracer`. There is no built-in
  way to task-locally combine a tracer with extra propagators, or several tracers at once. A wrapper type
  that groups several instruments behind one `Tracer` conformance, something like a `MultiplexTracer`, could
  close this gap without changing ``withTracer(_:_:)`` itself.

### Alternatives considered

**`withInstrument(_:_:)`: accept any `Instrument`.** Take any `Instrument`, not just a `Tracer`, so
propagation-only tools could be scoped too. Rejected. A scope built around a propagation-only `Instrument` on
its own is never useful. Span creation inside it silently finds no tracer and falls back to a ``NoOpTracer``,
with no compiler warning. Narrowing the parameter to `Tracer` turns that mistake into a compile error instead.

**A task-local-aware instrument installed as the bootstrap.** Instead of ``InstrumentationSystem`` reading a
task-local directly, install a dedicated wrapper instrument as the bootstrap that holds the task-local and
falls back to an inner ``NoOpInstrument``. This keeps the task-local read off the resolution path for
applications that only ``InstrumentationSystem/bootstrap(_:)`` and never scope. Rejected. It couples
``withTracer(_:_:)`` to the bootstrap state (it cannot be installed over a plainly-bootstrapped instrument),
introduces a self-reference hazard when ``InstrumentationSystem/instrument`` is passed back in, and needs
install-on-first-use. The always-checked slot is simpler and composes with any bootstrap.

**Store the tracer inside `ServiceContext`, not a separate slot.** Save the scoped tracer as a value inside
`ServiceContext` itself, alongside whatever it already carries, instead of on a dedicated task-local on
``InstrumentationSystem``. Code that already threads an explicit `ServiceContext`, rather than relying on the
ambient `ServiceContext.current`, gets the tracer propagated for free. That would also make it safe for an
application to move fully from ``bootstrap(_:)`` to `withTracer(_:_:)`, since no branch of the call graph could
silently lose the override. Rejected. It creates two public APIs, from two different packages, that can each
change the active tracer: `withTracer(_:_:)`, and `ServiceContext`'s own `$current.withValue(_:)`. Only the
first knows the tracer's key exists, so binding a freshly created `ServiceContext` through the second, an
ordinary and legitimate thing to do, has no way to carry the current tracer forward, and silently drops it with
no diagnostic. The separate task-local slot has the mirror problem, however. Some code manually saves and restores
`ServiceContext.current` across a boundary outside the task hierarchy, an event loop callback, for example.
That code restores the context, but not the tracer, because the two live in different places. Until someone
updates it to restore the tracer too, spans on that branch use the bootstrapped tracer instead of the scoped
one, which might not be installed at all.

**Accumulate nested scopes instead of replacing.** Push onto a task-local stack so a nested scope adds to,
rather than replaces, the enclosing one. Rejected. It is a hidden, surprising accumulation, and replacing is
simpler and easier to reason about.

**Expose `bootstrapInternal` for tests.** Rejected. It solves only testing, keeps the one-shot global model,
and gives libraries no per-request scoping.

**Pass the tracer to the closure** (`withTracer(x) { x in … }`). Rejected. Library code uses
``InstrumentationSystem/instrument`` and `withSpan`, not the tracer directly, and passing it would push people
toward direct use.
