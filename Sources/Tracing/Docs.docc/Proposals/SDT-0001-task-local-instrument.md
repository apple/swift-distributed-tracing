# SDT-0001: task-local instrument

A `withInstrument(_:_:)` free function that scopes an ``Instrument`` to the current task. Opt-in, with no
cost to apps that don't use it.

## Overview

- Proposal: SDT-0001
- Author(s): [Vladimir Kukushkin](https://github.com/kukushechkin)
- Status: **In Review**
- Issue: [apple/swift-distributed-tracing#168](https://github.com/apple/swift-distributed-tracing/issues/168)
- Implementation: TBD

### Introduction

This proposal adds the ``withInstrument(_:_:)`` free function. It runs a closure with a chosen ``Instrument``
active for the current task and any child tasks it spawns. Unlike ``InstrumentationSystem/bootstrap(_:)``,
which is set once per process, it can bind a different instrument per region of work, for example per test.

### Motivation

``InstrumentationSystem/bootstrap(_:)`` installs an instrument **once** per process. From then on, every
`withSpan` / `startSpan` call and every read of ``InstrumentationSystem/instrument`` resolves through that one
instrument. This fits "one tracer for the whole application". It makes per-test instruments hard, though: a
second `bootstrap` call crashes, so parallel tests can't each install their own.

### Proposed solution

``withInstrument(_:_:)`` runs a closure with an instrument active for the current task:

```swift
// Unit test — parallel-safe. The binding is task-local, so concurrent tests don't interfere.
@Test func spansAreCaptured() async {
    let tracer = InMemoryTracer()
    await withInstrument(tracer) {
        await withSpan("op") { _ in }   // emits into `tracer`
    }
    #expect(tracer.spans.count == 1)
}
```

Inside the closure — and in any child tasks it spawns — `instrument` is the active instrument, so span
creation (``InstrumentationSystem/tracer``, `withSpan` / `startSpan`) and propagation (`inject` / `extract`)
resolve through it. The binding is task-local, so a nested `withInstrument` applies only within its own
closure. It replaces rather than merges: to run several instruments at once, pass a ``MultiplexInstrument``,
exactly as you would to `bootstrap`.

### Detailed design

````swift
/// Makes `instrument` the active instrument for the current task and the child tasks it spawns, for the
/// duration of `operation`.
///
/// `withInstrument(_:_:)` works through a dedicated task-local instrument that the ``InstrumentationSystem``
/// holds as its bootstrap. The first call installs it — a one-time global bootstrap, done only when nothing
/// else is bootstrapped — and every call then sets `instrument` as the active instrument for the closure,
/// replacing any instrument an enclosing `withInstrument(_:_:)` set. Discovery (``InstrumentationSystem/tracer``,
/// free-function `withSpan` / `startSpan`) and propagation (`inject` / `extract`) resolve through `instrument`.
/// To keep several instruments active at once, pass a ``MultiplexInstrument`` built from the instruments you
/// hold.
///
/// ```swift
/// // Parallel-safe. The binding is task-local, so concurrent tests don't interfere.
/// @Test func spansAreCaptured() async {
///     let tracer = InMemoryTracer()
///     await withInstrument(tracer) {
///         await withSpan("op") { _ in }   // emits into `tracer`
///     }
///     #expect(tracer.spans.count == 1)
/// }
/// ```
///
/// > Important: This is an application-level facility — call it from code that owns the instrumentation setup,
/// > never from a library. It can install its instrument only when the ``InstrumentationSystem`` is otherwise
/// > un-bootstrapped. Calling it after a plain ``Instrument`` has been bootstrapped crashes. Libraries emit
/// > through ``InstrumentationSystem/instrument`` and `withSpan` / `startSpan`, which already observe whatever
/// > is active.
///
/// > Important: `instrument` replaces the active instrument for the scope, it does not merge with it. Include
/// > a tracer (directly or inside a ``MultiplexInstrument``) if you want spans recorded inside the closure.
/// > Passing ``InstrumentationSystem/instrument`` back in is rejected with a crash.
///
/// - Parameters:
///   - instrument: The instrument to make active for the duration of `operation`.
///   - operation: The closure to run with `instrument` active.
/// - Returns: The value returned by the closure.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public func withInstrument<Result, Failure: Error>(
    _ instrument: any Instrument,
    _ operation: () throws(Failure) -> Result
) throws(Failure) -> Result

#if compiler(>=6.2)
/// Makes `instrument` the active instrument for the current task and the child tasks it spawns, for the
/// duration of `operation`. See the synchronous `withInstrument(_:_:)` for the full discussion — replace
/// semantics, the application-level / plain-bootstrap rules, and the self-reference crash.
///
/// - Parameters:
///   - instrument: The instrument to make active for the duration of `operation`.
///   - operation: The async closure to run with `instrument` active.
/// - Returns: The value returned by the closure.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public nonisolated(nonsending) func withInstrument<Result, Failure: Error>(
    _ instrument: any Instrument,
    _ operation: nonisolated(nonsending) () async throws(Failure) -> Result
) async throws(Failure) -> Result
#else
/// Makes `instrument` the active instrument for the current task and the child tasks it spawns, for the
/// duration of `operation`. See the synchronous `withInstrument(_:_:)` for the full discussion — replace
/// semantics, the application-level / plain-bootstrap rules, and the self-reference crash.
///
/// - Parameters:
///   - instrument: The instrument to make active for the duration of `operation`.
///   - operation: The async closure to run with `instrument` active.
/// - Returns: The value returned by the closure.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public func withInstrument<Result, Failure: Error>(
    _ instrument: any Instrument,
    isolation: isolated (any Actor)? = #isolation,
    _ operation: () async throws(Failure) -> Result
) async throws(Failure) -> Result
#endif
````

That dedicated instrument is an internal type, `TaskLocalInstrument` — not public, so applications cannot
construct or name it. It holds the `@TaskLocal` override and falls back to an inner ``NoOpInstrument``.

### API stability

- Applications that never call ``withInstrument(_:_:)`` see no behavioral change.

### Future directions

- **Accumulate active instruments, not just replacing.** `withInstrument` replaces. A future variant —
  `withInstrument(merging:)`, or a form that passes the current instrument into a builder closure — could let
  a caller compose with whatever is already active without having to name it. The library would supply the
  concrete current instrument, keeping it safe from the self-reference crash that blocks composing
  ``InstrumentationSystem/instrument`` by hand today.

### Alternatives considered

**Task-local slot on ``InstrumentationSystem/instrument``.** Read the task-local on every `instrument` access
rather than behind an installed instrument. Rejected: it taxes every read even when no scope is active and
pushes scope-awareness into ``InstrumentationSystem``.

**Public `TaskLocalInstrument` to bootstrap directly.** Make `TaskLocalInstrument` a public type that
applications bootstrap directly (`InstrumentationSystem.bootstrap(TaskLocalInstrument(tracer))`), entering
scopes via a static `TaskLocalInstrument.with(_:_:)`. Rejected: a single free function matches the `withSpan`
/ `withMetricsFactory` precedent and avoids forcing a plain-vs-wrapped choice at bootstrap and compatibilities
with libraries doing instrumentation.

**Accumulate nested scopes instead of replacing.** Push onto a task-local stack so a nested scope adds to,
rather than replaces, the enclosing one. Rejected: it is a hidden, surprising accumulation, and the use case
it serves — augmenting whatever is already active — cannot be offered cleanly anyway, since
``InstrumentationSystem/instrument`` is a scope-aware wrapper rather than a concrete value (see above).
Replacing is simpler and matches swift-metrics' `withMetricsFactory`. Pass a ``MultiplexInstrument`` to run
several instruments at once.

**Task-local ``Tracer`` only.** Rejected: leaves ``InstrumentationSystem/instrument`` global, so `extract` /
`inject` wouldn't see the scope — a test would capture spans but miss incoming trace IDs.

**Expose `bootstrapInternal` for tests.** Rejected: solves only testing, keeps the one-shot global model, and
gives libraries no per-request scoping.

**Pass the instrument to the closure** (`withInstrument(x) { x in … }`). Rejected: library code uses
``InstrumentationSystem/instrument`` and `withSpan`, not the instrument directly. Passing it would push people
toward direct use.
