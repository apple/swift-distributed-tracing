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
) throws(Failure) -> Result {
    TaskLocalInstrument.requireNotSelfReferential(instrument)
    InstrumentationSystem.installTaskLocalInstrumentIfNeeded()
    return try TaskLocalInstrument.with(instrument, operation)
}

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
) async throws(Failure) -> Result {
    TaskLocalInstrument.requireNotSelfReferential(instrument)
    InstrumentationSystem.installTaskLocalInstrumentIfNeeded()
    return try await TaskLocalInstrument.with(instrument, operation)
}
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
) async throws(Failure) -> Result {
    TaskLocalInstrument.requireNotSelfReferential(instrument)
    InstrumentationSystem.installTaskLocalInstrumentIfNeeded()
    return try await TaskLocalInstrument.with(instrument, operation)
}
#endif
