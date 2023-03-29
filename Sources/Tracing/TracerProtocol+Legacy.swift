//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift Distributed Tracing project
// authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Dispatch
@_exported import Instrumentation
@_exported import InstrumentationBaggage

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
public protocol LegacyTracerProtocol: InstrumentProtocol {
    /// Start a new span returning an existential ``Span`` reference.
    ///
    /// This API will be deprecated as soon as Swift 5.9 is released, and the Swift 5.7 requiring `TracerProtocol`
    /// is recommended instead.
    ///
    /// The current task-local `Baggage` is picked up and provided to the underlying tracer.
    /// It is also possible to pass a specific `baggage` explicitly, in which case attempting
    /// to pick up the task-local baggage is prevented. This can be useful when we know that
    /// we're about to start a top-level span, or if a span should be started from a different,
    /// stored away previously,
    ///
    /// - Note: Legacy API, prefer using ``startSpan(_:baggage:ofKind:at:
    ///
    /// - Note: Prefer ``withSpan(_:baggage:ofKind:at:function:file:line:operation:)`` to start
    ///   a span as it automatically takes care of ending the span, and recording errors when thrown.
    ///   Use `startSpan` iff you need to pass the span manually to a different
    ///   location in your source code to end it.
    ///
    /// - Warning: You must `end()` the span when it the measured operation has completed explicitly,
    ///   otherwise the span object will potentially never be released nor reported.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - baggage: The `Baggage` providing information on where to start the new ``Span``.
    ///   - kind: The ``SpanKind`` of the new ``Span``.
    ///   - clock: The clock to use as time source for the start time of the ``Span``
    ///   - function: The function name in which the span was started
    ///   - fileID: The `fileID` where the span was started.
    ///   - line: The file line where the span was started.
    func startAnySpan<Clock: TracerClock>(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage,
        ofKind kind: SpanKind,
        clock: Clock,
        function: String,
        file fileID: String,
        line: UInt
    ) -> any Span

    /// Export all ended spans to the configured backend that have not yet been exported.
    ///
    /// This function should only be called in cases where it is absolutely necessary,
    /// such as when using some FaaS providers that may suspend the process after an invocation, but before the backend exports the completed spans.
    ///
    /// This function should not block indefinitely, implementations should offer a configurable timeout for flush operations.
    func forceFlush()
}

// ==== ------------------------------------------------------------------
// MARK: Legacy implementations for Swift 5.7

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
extension LegacyTracerProtocol {
    // ==== startSpan ---------------------------------------------------------

    /// Start a new span returning an existential ``Span`` reference.
    ///
    /// This API will be deprecated as soon as Swift 5.9 is released, and the Swift 5.7 requiring `TracerProtocol`
    /// is recommended instead.
    ///
    /// The current task-local `Baggage` is picked up and provided to the underlying tracer.
    /// It is also possible to pass a specific `baggage` explicitly, in which case attempting
    /// to pick up the task-local baggage is prevented. This can be useful when we know that
    /// we're about to start a top-level span, or if a span should be started from a different,
    /// stored away previously,
    ///
    /// - Note: Legacy API, prefer using ``startSpan(_:baggage:ofKind:at:
    ///
    /// - Note: Prefer ``withSpan(_:baggage:ofKind:at:function:file:line:operation:)`` to start
    ///   a span as it automatically takes care of ending the span, and recording errors when thrown.
    ///   Use `startSpan` iff you need to pass the span manually to a different
    ///   location in your source code to end it.
    ///
    /// - Warning: You must `end()` the span when it the measured operation has completed explicitly,
    ///   otherwise the span object will potentially never be released nor reported.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - baggage: The `Baggage` providing information on where to start the new ``Span``.
    ///   - kind: The ``SpanKind`` of the new ``Span``.
    ///   - clock: The clock to use as time source for the start time of the ``Span``
    ///   - function: The function name in which the span was started
    ///   - fileID: The `fileID` where the span was started.
    ///   - line: The file line where the span was started.
    public func startAnySpan<Clock: TracerClock>(
        _ operationName: String,
        clock: Clock,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line
    ) -> any Span {
        self.startAnySpan(
            operationName,
            baggage: baggage(),
            ofKind: kind,
            clock: clock,
            function: function,
            file: fileID,
            line: line
        )
    }

    public func startAnySpan(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line
    ) -> any Span {
        self.startAnySpan(
            operationName,
            baggage: baggage(),
            ofKind: kind,
            clock: DefaultTracerClock(),
            function: function,
            file: fileID,
            line: line
        )
    }

    // ==== withAnySpan + sync ------------------------------------------------

    public func withAnySpan<T, Clock: TracerClock>(
        _ operationName: String,
        clock: Clock,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Span) throws -> T
    ) rethrows -> T {
        let span = self.startAnySpan(
            operationName,
            baggage: baggage(),
            ofKind: kind,
            clock: clock,
            function: function,
            file: fileID,
            line: line
        )
        defer { span.end() }
        do {
            return try Baggage.$current.withValue(span.baggage) {
                try operation(span)
            }
        } catch {
            span.recordError(error)
            throw error // rethrow
        }
    }

    public func withAnySpan<T>(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Span) throws -> T
    ) rethrows -> T {
        try self.withAnySpan(
            operationName,
            clock: DefaultTracerClock(),
            baggage: baggage(),
            ofKind: kind,
            function: function,
            file: fileID,
            line: line,
            operation
        )
    }

    // ==== withAnySpan async -------------------------------------------------

    public func withAnySpan<T, Clock: TracerClock>(
        _ operationName: String,
        clock: Clock,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Span) async throws -> T
    ) async rethrows -> T {
        let span = self.startAnySpan(
            operationName,
            clock: clock,
            baggage: baggage(),
            ofKind: kind,
            function: function,
            file: fileID,
            line: line
        )
        defer { span.end() }
        do {
            return try await Baggage.$current.withValue(span.baggage) {
                try await operation(span)
            }
        } catch {
            span.recordError(error)
            throw error // rethrow
        }
    }

    public func withAnySpan<T>(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Span) async throws -> T
    ) async rethrows -> T {
        let span = self.startAnySpan(
            operationName,
            clock: DefaultTracerClock(),
            baggage: baggage(),
            ofKind: kind,
            function: function,
            file: fileID,
            line: line
        )
        defer { span.end() }
        do {
            return try await Baggage.$current.withValue(span.baggage) {
                try await operation(span)
            }
        } catch {
            span.recordError(error)
            throw error // rethrow
        }
    }
}

#if swift(>=5.7.0)
// Provide compatibility shims of the `...AnySpan` APIs to the 5.7 requiring `TracerProtocol`.

extension TracerProtocol {
    /// Start a new span returning an existential ``Span`` reference.
    ///
    /// This API will be deprecated as soon as Swift 5.9 is released, and the Swift 5.7 requiring `TracerProtocol`
    /// is recommended instead.
    ///
    /// The current task-local `Baggage` is picked up and provided to the underlying tracer.
    /// It is also possible to pass a specific `baggage` explicitly, in which case attempting
    /// to pick up the task-local baggage is prevented. This can be useful when we know that
    /// we're about to start a top-level span, or if a span should be started from a different,
    /// stored away previously,
    ///
    /// - Note: Legacy API, prefer using ``startSpan(_:baggage:ofKind:at:
    ///
    /// - Note: Prefer ``withSpan(_:baggage:ofKind:at:function:file:line:operation:)`` to start
    ///   a span as it automatically takes care of ending the span, and recording errors when thrown.
    ///   Use `startSpan` iff you need to pass the span manually to a different
    ///   location in your source code to end it.
    ///
    /// - Warning: You must `end()` the span when it the measured operation has completed explicitly,
    ///   otherwise the span object will potentially never be released nor reported.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - baggage: The `Baggage` providing information on where to start the new ``Span``.
    ///   - kind: The ``SpanKind`` of the new ``Span``.
    ///   - clock: The clock to use as time source for the start time of the ``Span``
    ///   - function: The function name in which the span was started
    ///   - fileID: The `fileID` where the span was started.
    ///   - line: The file line where the span was started.
    public func startAnySpan(
        _ operationName: String,
        clock: some TracerClock = DefaultTracerClock(),
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line
    ) -> any Span {
        self.startSpan(
            operationName,
            baggage: baggage(),
            ofKind: kind,
            clock: clock,
            function: function,
            file: fileID,
            line: line
        )
    }

    /// Start a new ``Span`` and automatically end when the `operation` completes,
    /// including recording the `error` in case the operation throws.
    ///
    /// This API will be deprecated as soon as Swift 5.9 is released, and the Swift 5.7 requiring `TracerProtocol`
    /// is recommended instead.
    ///
    /// The current task-local `Baggage` is picked up and provided to the underlying tracer.
    /// It is also possible to pass a specific `baggage` explicitly, in which case attempting
    /// to pick up the task-local baggage is prevented. This can be useful when we know that
    /// we're about to start a top-level span, or if a span should be started from a different,
    /// stored away previously,
    ///
    /// - Note: Legacy API, prefer using ``startSpan(_:baggage:ofKind:at:
    ///
    /// - Note: Prefer ``withSpan(_:baggage:ofKind:at:function:file:line:operation:)`` to start
    ///   a span as it automatically takes care of ending the span, and recording errors when thrown.
    ///   Use `startSpan` iff you need to pass the span manually to a different
    ///   location in your source code to end it.
    ///
    /// - Warning: You must `end()` the span when it the measured operation has completed explicitly,
    ///   otherwise the span object will potentially never be released nor reported.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - baggage: The `Baggage` providing information on where to start the new ``Span``.
    ///   - kind: The ``SpanKind`` of the new ``Span``.
    ///   - clock: The clock to use as time source for the start time of the ``Span``
    ///   - function: The function name in which the span was started
    ///   - fileID: The `fileID` where the span was started.
    ///   - line: The file line where the span was started.
    ///   - operation: The operation that this span should be measuring
    /// - Returns: the value returned by `operation`
    /// - Throws: the error the `operation` has thrown (if any)
    public func withAnySpan<T>(
        _ operationName: String,
        clock: some TracerClock = DefaultTracerClock(),
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Span) throws -> T
    ) rethrows -> T {
        try self.withSpan(
            operationName,
            baggage: baggage(),
            ofKind: kind,
            clock: clock,
            function: function,
            file: fileID,
            line: line
        ) { span in
            try operation(span)
        }
    }

    /// Start a new ``Span`` and automatically end when the `operation` completes,
    /// including recording the `error` in case the operation throws.
    ///
    /// This API will be deprecated as soon as Swift 5.9 is released, and the Swift 5.7 requiring `TracerProtocol`
    /// is recommended instead.
    ///
    /// The current task-local `Baggage` is picked up and provided to the underlying tracer.
    /// It is also possible to pass a specific `baggage` explicitly, in which case attempting
    /// to pick up the task-local baggage is prevented. This can be useful when we know that
    /// we're about to start a top-level span, or if a span should be started from a different,
    /// stored away previously,
    ///
    /// - Note: Legacy API, prefer using ``startSpan(_:baggage:ofKind:at:
    ///
    /// - Note: Prefer ``withSpan(_:baggage:ofKind:at:function:file:line:operation:)`` to start
    ///   a span as it automatically takes care of ending the span, and recording errors when thrown.
    ///   Use `startSpan` iff you need to pass the span manually to a different
    ///   location in your source code to end it.
    ///
    /// - Warning: You must `end()` the span when it the measured operation has completed explicitly,
    ///   otherwise the span object will potentially never be released nor reported.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - baggage: The `Baggage` providing information on where to start the new ``Span``.
    ///   - kind: The ``SpanKind`` of the new ``Span``.
    ///   - clock: The clock to use as time source for the start time of the ``Span``
    ///   - function: The function name in which the span was started
    ///   - fileID: The `fileID` where the span was started.
    ///   - line: The file line where the span was started.
    ///   - operation: The operation that this span should be measuring
    /// - Returns: the value returned by `operation`
    /// - Throws: the error the `operation` has thrown (if any)
    public func withAnySpan<T>(
        _ operationName: String,
        clock: some TracerClock = DefaultTracerClock(),
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        @_inheritActorContext @_implicitSelfCapture _ operation: (any Span) async throws -> T
    ) async rethrows -> T {
        try await self.withSpan(
            operationName,
            baggage: baggage(),
            ofKind: kind,
            clock: clock,
            function: function,
            file: fileID,
            line: line
        ) { span in
            try await operation(span)
        }
    }
}
#endif
