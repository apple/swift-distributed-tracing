# SDT-0001: task-local instrument

A `withInstrument(_:_:)` free function that scopes an ``Instrument`` to the current task, resolved ahead of
the process-wide ``InstrumentationSystem/bootstrap(_:)`` and falling back to it outside the scope.

## Overview

- Proposal: SDT-0001
- Author(s): [Vladimir Kukushkin](https://github.com/kukushechkin)
- Status: **In Review**
- Issue: [apple/swift-distributed-tracing#168](https://github.com/apple/swift-distributed-tracing/issues/168)
- Implementation: on the `SDT-0001-task-local-instrument-implementation` branch

### Introduction

This proposal adds the ``withInstrument(_:_:)`` free function. It runs a closure with a chosen ``Instrument``
active for the current task and any child tasks it spawns. Unlike ``InstrumentationSystem/bootstrap(_:)``,
which is set once per process, it can bind a different instrument per region of work, for example per test. The
binding is resolved ahead of the bootstrapped instrument and falls back to it outside the scope.

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
    #expect(tracer.finishedSpans.count == 1)
}
```

Inside the closure — and in any child tasks it spawns — `instrument` is the active instrument, so span
creation (``InstrumentationSystem/tracer``, `withSpan` / `startSpan`) and propagation (`inject` / `extract`)
resolve it ahead of whatever ``InstrumentationSystem/bootstrap(_:)`` set. Outside the closure, resolution falls
back to the bootstrapped instrument. The binding is task-local, so a nested `withInstrument` applies only
within its own closure and replaces rather than merges — to run several instruments at once, pass a
``MultiplexInstrument``, exactly as you would to `bootstrap`. Propagation runs every member of a
``MultiplexInstrument``, but span creation uses the first ``Tracer`` in it.

### Detailed design

````swift
/// Makes `instrument` the active instrument for the current task and the child tasks it spawns, for the
/// duration of `operation`.
///
/// Inside the closure, ``InstrumentationSystem/instrument``, discovery (``InstrumentationSystem/tracer``,
/// free-function `withSpan` / `startSpan`), and propagation (`inject` / `extract`) resolve `instrument` ahead
/// of whatever was set with ``InstrumentationSystem/bootstrap(_:)``. Outside the closure, resolution falls back
/// to the bootstrapped instrument. An unstructured `Task { }` inherits the binding, but `Task.detached` does
/// not. A nested `withInstrument(_:_:)` replaces the active instrument for its own scope rather than merging
/// with it. To keep several instruments active at once, pass a ``MultiplexInstrument`` built from the
/// instruments you hold.
///
/// ```swift
/// // Parallel-safe. The binding is task-local, so concurrent tests don't interfere.
/// @Test func spansAreCaptured() async {
///     let tracer = InMemoryTracer()
///     await withInstrument(tracer) {
///         await withSpan("op") { _ in }   // emits into `tracer`
///     }
///     #expect(tracer.finishedSpans.count == 1)
/// }
/// ```
///
/// This chooses the active *instrument* (the backend), not the trace *context* — propagating context is
/// ``ServiceContext``'s job. It does not alter cancellation: an error thrown by `operation`, including
/// `CancellationError`, propagates out unchanged.
///
/// > Note: This is a scoped alternative to ``InstrumentationSystem/bootstrap(_:)``, resolved ahead of it for
/// > the duration of `operation`. ``InstrumentationSystem/instrument`` and `withSpan` / `startSpan` observe
/// > whichever is active.
///
/// - Parameters:
///   - instrument: The instrument to make active for the duration of `operation`.
///   - operation: The closure to run with `instrument` active.
/// - Returns: The value returned by the closure.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public func withInstrument<Result, Failure: Error>(
    _ instrument: any Instrument,
    _ operation: () throws(Failure) -> Result
) throws(Failure) -> Result

#if compiler(>=6.2)
/// Makes `instrument` the active instrument for the current task and the child tasks it spawns, for the
/// duration of `operation`. See the synchronous `withInstrument(_:_:)` for the full discussion — replace
/// semantics and fallback to the bootstrapped instrument.
///
/// - Parameters:
///   - instrument: The instrument to make active for the duration of `operation`.
///   - operation: The async closure to run with `instrument` active.
/// - Returns: The value returned by the closure.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public nonisolated(nonsending) func withInstrument<Result, Failure: Error>(
    _ instrument: any Instrument,
    _ operation: nonisolated(nonsending) () async throws(Failure) -> Result
) async throws(Failure) -> Result
#else
/// Makes `instrument` the active instrument for the current task and the child tasks it spawns, for the
/// duration of `operation`. See the synchronous `withInstrument(_:_:)` for the full discussion — replace
/// semantics and fallback to the bootstrapped instrument.
///
/// - Parameters:
///   - instrument: The instrument to make active for the duration of `operation`.
///   - operation: The async closure to run with `instrument` active.
/// - Returns: The value returned by the closure.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public func withInstrument<Result, Failure: Error>(
    _ instrument: any Instrument,
    isolation: isolated (any Actor)? = #isolation,
    _ operation: () async throws(Failure) -> Result
) async throws(Failure) -> Result
#endif
````

The scope is backed by an `@TaskLocal` on ``InstrumentationSystem``. ``InstrumentationSystem/instrument`` and
``InstrumentationSystem/_findInstrument(where:)`` resolve it ahead of the bootstrapped instrument, falling back
to the bootstrap when no scope is active. There is no wrapper instrument, and nothing is installed on first use.

The overload shapes follow sibling-package precedent: the free-function form and typed-throws forwarding mirror
swift-metrics' `withMetricsFactory`, and the async overload's `nonisolated(nonsending)` (Swift 6.2+) versus
`isolation: isolated (any Actor)? = #isolation` (earlier compilers) split mirrors swift-service-context's
`ServiceContext.withValue(_:isolation:operation:)`.

### API stability

- Purely additive: a new free function and an internal task-local. Existing signatures are unchanged.
- Applications that never call ``withInstrument(_:_:)`` see no behavioral change — resolution falls back to the
  bootstrapped instrument. Instrument lookup now consults a task-local before the bootstrap.
- That task-local read is on every lookup, including the per-span `withSpan` / `startSpan` path. While adding
  task-local instrument to the hot path adds a ~5% overhead comparing to the old task-local-free implementation,
  actually **adopting task-local instrument improves** `withSpan` performance by ~5% measured against a
  `NoOp` tracer. Against a real tracer, whose per-span work dominates, the relative cost is even smaller.
- The `withInstrument(_:_:)` overloads are `@inlinable`, and the backing task-local and its helper are
  `@usableFromInline`, mirroring swift-metrics' `withMetricsFactory`, so the task-local bind can inline into the
  caller. This is a source-distributed package, so `@inlinable` affects cross-module optimization, not ABI.

### Future directions

- **A `withInstrument(merging:)` convenience.** `withInstrument` replaces the active instrument. Composing with
  whatever is already active is possible by hand today —
  `withInstrument(MultiplexInstrument([InstrumentationSystem.instrument, myTracer]))` — because
  ``InstrumentationSystem/instrument`` returns the concrete active instrument. A `withInstrument(merging:)`
  variant could build that ``MultiplexInstrument`` for the caller.

### Alternatives considered

**A task-local-aware instrument installed as the bootstrap.** Instead of ``InstrumentationSystem`` reading a
task-local directly, install a dedicated wrapper instrument as the bootstrap that holds the task-local and
falls back to an inner ``NoOpInstrument``. This keeps the task-local read off the resolution path for
applications that only ``InstrumentationSystem/bootstrap(_:)`` and never scope. Rejected: it couples
``withInstrument(_:_:)`` to the bootstrap state (it cannot be installed over a plainly-bootstrapped instrument),
introduces a self-reference hazard when ``InstrumentationSystem/instrument`` is passed back in, and needs
install-on-first-use. The always-checked slot is simpler and composes with any bootstrap.

**A public task-local instrument type to bootstrap directly.** Expose a public wrapper type that applications
bootstrap directly and enter scopes on via a static method. Rejected: a single free function matches the
`withSpan` / `withMetricsFactory` precedent, and it avoids forcing a plain-vs-scoped choice at bootstrap time.

**Accumulate nested scopes instead of replacing.** Push onto a task-local stack so a nested scope adds to,
rather than replaces, the enclosing one. Rejected: it is a hidden, surprising accumulation. Replacing is
simpler and matches swift-metrics' `withMetricsFactory`. Augmenting whatever is already active is available by
composing a ``MultiplexInstrument`` with ``InstrumentationSystem/instrument`` (see Future directions), and
running several instruments at once is just passing a ``MultiplexInstrument``.

**Task-local ``Tracer`` only.** Rejected: leaves ``InstrumentationSystem/instrument`` global, so `extract` /
`inject` wouldn't see the scope — a test would capture spans but miss incoming trace IDs.

**Expose `bootstrapInternal` for tests.** Rejected: solves only testing, keeps the one-shot global model, and
gives libraries no per-request scoping.

**Pass the instrument to the closure** (`withInstrument(x) { x in … }`). Rejected: library code uses
``InstrumentationSystem/instrument`` and `withSpan`, not the instrument directly. Passing it would push people
toward direct use.
