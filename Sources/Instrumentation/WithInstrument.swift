//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2025 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

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
) throws(Failure) -> Result {
    do {
        return try InstrumentationSystem.withTaskLocalInstrument(instrument, operation: operation)
    } catch {
        // FIXME: remove when `TaskLocal.withValue` gains typed-throws support.
        // Safe today: `operation` has typed throws `throws(Failure)`, and `TaskLocal.withValue` is `rethrows`
        // — it introduces no errors of its own, so every error reaching this catch originated from `operation`
        // and is therefore of type `Failure`.
        throw error as! Failure
    }
}

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
) async throws(Failure) -> Result {
    do {
        return try await InstrumentationSystem.withTaskLocalInstrument(instrument, operation: operation)
    } catch {
        // FIXME: remove when `TaskLocal.withValue` gains typed-throws support. Safe for the same reason as the
        // synchronous variant above.
        throw error as! Failure
    }
}
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
) async throws(Failure) -> Result {
    do {
        return try await InstrumentationSystem.withTaskLocalInstrument(
            instrument,
            isolation: isolation,
            operation: operation
        )
    } catch {
        // FIXME: remove when `TaskLocal.withValue` gains typed-throws support. Safe for the same reason as the
        // synchronous variant above.
        throw error as! Failure
    }
}
#endif
