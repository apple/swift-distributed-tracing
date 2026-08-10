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
@inlinable
public func withTracer<Result, Failure: Error>(
    _ tracer: any Tracer,
    _ operation: () throws(Failure) -> Result
) throws(Failure) -> Result {
    do {
        return try InstrumentationSystem.withTaskLocalInstrument(tracer, operation: operation)
    } catch {
        // FIXME: remove when `TaskLocal.withValue` gains typed-throws support.
        // Safe today: `operation` has typed throws `throws(Failure)`, and `TaskLocal.withValue` is `rethrows`
        // — it introduces no errors of its own, so every error reaching this catch originated from `operation`
        // and is therefore of type `Failure`.
        throw error as! Failure
    }
}

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
@inlinable
public nonisolated(nonsending) func withTracer<Result, Failure: Error>(
    _ tracer: any Tracer,
    _ operation: nonisolated(nonsending) () async throws(Failure) -> Result
) async throws(Failure) -> Result {
    do {
        return try await InstrumentationSystem.withTaskLocalInstrument(tracer, operation: operation)
    } catch {
        // FIXME: remove when `TaskLocal.withValue` gains typed-throws support. Safe for the same reason as the
        // synchronous variant above.
        throw error as! Failure
    }
}
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
@inlinable
public func withTracer<Result, Failure: Error>(
    _ tracer: any Tracer,
    isolation: isolated (any Actor)? = #isolation,
    _ operation: () async throws(Failure) -> Result
) async throws(Failure) -> Result {
    do {
        return try await InstrumentationSystem.withTaskLocalInstrument(
            tracer,
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
