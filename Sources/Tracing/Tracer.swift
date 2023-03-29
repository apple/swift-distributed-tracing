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

/// Convenience access to static `startSpan` and `withSpan` APIs invoked on the globally bootstrapped tracer.
///
/// If no tracer was bootstrapped using ``InstrumentationSystem/bootstrap(_:)`` these operations are no-ops.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
public enum Tracer {
    // namespace for short-hand operations on global bootstrapped tracer
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
extension Tracer {
    /// Start a new ``Span`` using the global bootstrapped tracer reimplementation.
    ///
    /// The current task-local `Baggage` is picked up and provided to the underlying tracer.
    /// It is also possible to pass a specific `baggage` explicitly, in which case attempting
    /// to pick up the task-local baggage is prevented. This can be useful when we know that
    /// we're about to start a top-level span, or if a span should be started from a different,
    /// stored away previously,
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
    ///   - clock: The clock to use as time source for the start time of the ``Span``
    ///   - baggage: The `Baggage` providing information on where to start the new ``Span``.
    ///   - kind: The ``SpanKind`` of the new ``Span``.
    ///   - function: The function name in which the span was started
    ///   - fileID: The `fileID` where the span was started.
    ///   - line: The file line where the span was started.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
    static func startSpan<Clock: TracerClock>(
        _ operationName: String,
        clock: Clock,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line
    ) -> any Span {
        // Effectively these end up calling the same method, however
        // we try to not use the deprecated methods ourselves anyway
        InstrumentationSystem.legacyTracer.startAnySpan(
            operationName,
            clock: clock,
            baggage: baggage(),
            ofKind: kind,
            function: function,
            file: fileID,
            line: line
        )
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
    static func startSpan(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line
    ) -> any Span {
        // Effectively these end up calling the same method, however
        // we try to not use the deprecated methods ourselves anyway
        InstrumentationSystem.legacyTracer.startAnySpan(
            operationName,
            clock: DefaultTracerClock(),
            baggage: baggage(),
            ofKind: kind,
            function: function,
            file: fileID,
            line: line
        )
    }

    #if swift(>=5.7.0)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
    static func startSpan(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        clock: some TracerClock = DefaultTracerClock(),
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line
    ) -> any Span {
        // Effectively these end up calling the same method, however
        // we try to not use the deprecated methods ourselves anyway
        InstrumentationSystem.tracer.startAnySpan(
            operationName,
            clock: clock,
            baggage: baggage(),
            ofKind: kind,
            function: function,
            file: fileID,
            line: line
        )
    }
    #endif

    // ==== withSpan + sync ---------------------------------------------------

    /// Start a new ``Span`` and automatically end when the `operation` completes,
    /// including recording the `error` in case the operation throws.
    ///
    /// The current task-local `Baggage` is picked up and provided to the underlying tracer.
    /// It is also possible to pass a specific `baggage` explicitly, in which case attempting
    /// to pick up the task-local baggage is prevented. This can be useful when we know that
    /// we're about to start a top-level span, or if a span should be started from a different,
    /// stored away previously,
    ///
    /// - Warning: You MUST NOT ``Span/end()`` the span explicitly, because at the end of the `withSpan`
    ///   operation closure returning the span will be closed automatically.
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
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
    public static func withSpan<T, Clock: TracerClock>(
        _ operationName: String,
        clock: Clock,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Span) throws -> T
    ) rethrows -> T {
        try InstrumentationSystem.legacyTracer.withAnySpan(
            operationName,
            clock: DefaultTracerClock(),
            baggage: baggage(),
            ofKind: kind,
            function: function,
            file: fileID,
            line: line
        ) { anySpan in
            try operation(anySpan)
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
    public static func withSpan<T>(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Span) throws -> T
    ) rethrows -> T {
        try InstrumentationSystem.legacyTracer.withAnySpan(
            operationName,
            clock: DefaultTracerClock(),
            baggage: baggage(),
            ofKind: kind,
            function: function,
            file: fileID,
            line: line
        ) { anySpan in
            try operation(anySpan)
        }
    }

    #if swift(>=5.7.0)
    public static func withSpan<T>(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        clock: some TracerClock = DefaultTracerClock(),
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Span) throws -> T
    ) rethrows -> T {
        try InstrumentationSystem.legacyTracer.withAnySpan(
            operationName,
            clock: clock,
            baggage: baggage(),
            ofKind: kind,
            function: function,
            file: fileID,
            line: line
        ) { anySpan in
            try operation(anySpan)
        }
    }
    #endif

    // ==== withSpan + async --------------------------------------------------

    /// Start a new ``Span`` and automatically end when the `operation` completes,
    /// including recording the `error` in case the operation throws.
    ///
    /// The current task-local `Baggage` is picked up and provided to the underlying tracer.
    /// It is also possible to pass a specific `baggage` explicitly, in which case attempting
    /// to pick up the task-local baggage is prevented. This can be useful when we know that
    /// we're about to start a top-level span, or if a span should be started from a different,
    /// stored away previously,
    ///
    /// - Warning: You MUST NOT ``Span/end()`` the span explicitly, because at the end of the `withSpan`
    ///   operation closure returning the span will be closed automatically.
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
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
    public static func withSpan<T, Clock: TracerClock>(
        _ operationName: String,
        clock: Clock,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Span) async throws -> T
    ) async rethrows -> T {
        try await InstrumentationSystem.legacyTracer.withAnySpan(
            operationName,
            clock: DefaultTracerClock(),
            baggage: baggage(),
            ofKind: kind,
            function: function,
            file: fileID,
            line: line
        ) { anySpan in
            try await operation(anySpan)
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
    public static func withSpan<T>(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Span) async throws -> T
    ) async rethrows -> T {
        try await InstrumentationSystem.legacyTracer.withAnySpan(
            operationName,
            clock: DefaultTracerClock(),
            baggage: baggage(),
            ofKind: kind,
            function: function,
            file: fileID,
            line: line
        ) { anySpan in
            try await operation(anySpan)
        }
    }

    #if swift(>=5.7.0)
    public static func withSpan<T>(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        clock: some TracerClock = DefaultTracerClock(),
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Span) async throws -> T
    ) async rethrows -> T {
        try await InstrumentationSystem.legacyTracer.withAnySpan(
            operationName,
            clock: clock,
            baggage: baggage(),
            ofKind: kind,
            function: function,
            file: fileID,
            line: line
        ) { anySpan in
            try await operation(anySpan)
        }
    }
    #endif
}
