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

/// Makes the tracer the active instrument for the current task and any child tasks it spawns.
///
/// The task-local tracer exists for the duration of `operation`. Takes priority over the bootstrapped
/// instrument for both span creation and propagation, since a `Tracer` is an `Instrument`.
///
/// ```swift
/// @Test func spansAreCaptured() async {
///     let tracer = InMemoryTracer()
///     await withTracer(tracer) {
///         await withSpan("op") { _ in }   // emits into `tracer`
///     }
///     #expect(tracer.finishedSpans.count == 1)
/// }
/// ```
///
/// See <doc:TraceYourApplication#Scope-a-tracer-using-withTracer> for task inheritance, nesting, and
/// multi-instrument scoping.
///
/// - Parameters:
///   - tracer: The tracer to make active for the duration of `operation`.
///   - operation: The closure to run with `tracer` active.
/// - Returns: The value returned by the closure.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public func withTracer<Result, Failure: Error>(
    _ tracer: any Tracer,
    _ operation: () throws(Failure) -> Result
) throws(Failure) -> Result {
    do {
        return try InstrumentationSystem.withTaskLocalInstrument(tracer, operation: operation)
    } catch {
        // FIXME: remove when `TaskLocal.withValue` gains typed-throws support.
        // Safe today: `operation` has typed throws `throws(Failure)`, and `TaskLocal.withValue` is `rethrows`.
        // It introduces no errors of its own, so every error reaching this catch originated from `operation`
        // and is therefore of type `Failure`.
        throw error as! Failure
    }
}

#if compiler(>=6.2)
/// Makes the tracer the active instrument for the current task and any child tasks it spawns.
///
/// The task-local tracer exists for the duration of `operation`. Takes priority over the bootstrapped
/// instrument for both span creation and propagation, since a `Tracer` is an `Instrument`.
///
/// ```swift
/// @Test func spansAreCaptured() async {
///     let tracer = InMemoryTracer()
///     await withTracer(tracer) {
///         await withSpan("op") { _ in }   // emits into `tracer`
///     }
///     #expect(tracer.finishedSpans.count == 1)
/// }
/// ```
///
/// See <doc:TraceYourApplication#Scope-a-tracer-using-withTracer> for task inheritance, nesting, and
/// multi-instrument scoping.
///
/// - Parameters:
///   - tracer: The tracer to make active for the duration of `operation`.
///   - operation: The async closure to run with `tracer` active.
/// - Returns: The value returned by the closure.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
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
/// Makes the tracer the active instrument for the current task and any child tasks it spawns.
///
/// The task-local tracer exists for the duration of `operation`. Takes priority over the bootstrapped
/// instrument for both span creation and propagation, since a `Tracer` is an `Instrument`.
///
/// ```swift
/// @Test func spansAreCaptured() async {
///     let tracer = InMemoryTracer()
///     await withTracer(tracer) {
///         await withSpan("op") { _ in }   // emits into `tracer`
///     }
///     #expect(tracer.finishedSpans.count == 1)
/// }
/// ```
///
/// See <doc:TraceYourApplication#Scope-a-tracer-using-withTracer> for task inheritance, nesting, and
/// multi-instrument scoping.
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
