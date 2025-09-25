//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_exported import Instrumentation
@_exported import ServiceContextModule

/// Start a new span using the global bootstrapped tracer reimplementation.
///
/// The current task-local `ServiceContext` is picked up and provided to the underlying tracer.
/// It is also possible to pass a specific `context` explicitly, in which case attempting
/// to pick up the task-local context is prevented. This can be useful when we know that
/// we're about to start a top-level span, or if a span should be started from a different,
/// stored away previously,
///
/// - Note: Prefer ``withSpan(_:context:ofKind:at:function:file:line:_:)-8gw3v`` to start
///   a span as it automatically takes care of ending the span, and recording errors when thrown.
///   Use `startSpan` iff you need to pass the span manually to a different
///   location in your source code to end it.
///
/// - Warning: You must `end()` the span when it the measured operation has completed explicitly,
///   otherwise the span object will potentially never be released nor reported.
///
/// - Parameters:
///   - operationName: The name of the operation being traced. This may be a handler function, a database call, and so on.
///   - instant: The time instant at which the span started.
///   - context: The `ServiceContext` that provides information on where to start the span.
///   - kind: The kind of span.
///   - function: The function name in which the span was started.
///   - fileID: The `fileID` where the span was started.
///   - line: The file line where the span was started.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
public func startSpan<Instant: TracerInstant>(
    _ operationName: String,
    at instant: @autoclosure () -> Instant,
    context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
    ofKind kind: SpanKind = .internal,
    function: String = #function,
    file fileID: String = #fileID,
    line: UInt = #line
) -> any Span {
    // Effectively these end up calling the same method, however
    // we try to not use the deprecated methods ourselves anyway
    InstrumentationSystem.legacyTracer.startAnySpan(
        operationName,
        at: instant(),
        context: context(),
        ofKind: kind,
        function: function,
        file: fileID,
        line: line
    )
}

/// Start a new span using the global bootstrapped tracer reimplementation.
///
/// The current task-local `ServiceContext` is picked up and provided to the underlying tracer.
/// It is also possible to pass a specific `context` explicitly, in which case attempting
/// to pick up the task-local context is prevented. This can be useful when we know that
/// we're about to start a top-level span, or if a span should be started from a different,
/// stored away previously,
///
/// - Note: Prefer ``withSpan(_:context:ofKind:at:function:file:line:_:)-8gw3v`` to start
///   a span as it automatically takes care of ending the span, and recording errors when thrown.
///   Use `startSpan` iff you need to pass the span manually to a different
///   location in your source code to end it.
///
/// - Warning: You must `end()` the span when it the measured operation has completed explicitly,
///   otherwise the span object will potentially never be released nor reported.
///
/// - Parameters:
///   - operationName: The name of the operation being traced. This may be a handler function, a database call, and so on.
///   - context: The `ServiceContext` that provides information on where to start the span.
///   - kind: The kind of span.
///   - function: The function name in which the span was started.
///   - fileID: The `fileID` where the span was started.
///   - line: The file line where the span was started.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
public func startSpan(
    _ operationName: String,
    context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
    ofKind kind: SpanKind = .internal,
    function: String = #function,
    file fileID: String = #fileID,
    line: UInt = #line
) -> any Span {
    // Effectively these end up calling the same method, however
    // we try to not use the deprecated methods ourselves anyway
    InstrumentationSystem.legacyTracer.startAnySpan(
        operationName,
        at: DefaultTracerClock.now,
        context: context(),
        ofKind: kind,
        function: function,
        file: fileID,
        line: line
    )
}

/// Start a new span using the global bootstrapped tracer reimplementation.
///
/// The current task-local `ServiceContext` is picked up and provided to the underlying tracer.
/// It is also possible to pass a specific `context` explicitly, in which case attempting
/// to pick up the task-local context is prevented. This can be useful when we know that
/// we're about to start a top-level span, or if a span should be started from a different,
/// stored away previously,
///
/// - Note: Prefer ``withSpan(_:context:ofKind:at:function:file:line:_:)-8gw3v`` to start
///   a span as it automatically takes care of ending the span, and recording errors when thrown.
///   Use `startSpan` iff you need to pass the span manually to a different
///   location in your source code to end it.
///
/// - Warning: You must `end()` the span when it the measured operation has completed explicitly,
///   otherwise the span object will potentially never be released nor reported.
///
/// - Parameters:
///   - operationName: The name of the operation being traced. This may be a handler function, a database call, and so on.
///   - context: The `ServiceContext` that provides information on where to start the span.
///   - kind: The kind of span.
///   - instant: The time instant at which the span started.
///   - function: The function name in which the span was started.
///   - fileID: The `fileID` where the span was started.
///   - line: The file line where the span was started.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
public func startSpan(
    _ operationName: String,
    context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
    ofKind kind: SpanKind = .internal,
    at instant: @autoclosure () -> some TracerInstant = DefaultTracerClock.now,
    function: String = #function,
    file fileID: String = #fileID,
    line: UInt = #line
) -> any Span {
    // Effectively these end up calling the same method, however
    // we try to not use the deprecated methods ourselves anyway
    InstrumentationSystem.tracer.startAnySpan(
        operationName,
        at: instant(),
        context: context(),
        ofKind: kind,
        function: function,
        file: fileID,
        line: line
    )
}

// ==== withSpan + sync ---------------------------------------------------

/// Start a new span and automatically end when the operation completes,
/// including recording the error in case the operation throws.
///
/// The current task-local `ServiceContext` is picked up and provided to the underlying tracer.
/// It is also possible to pass a specific `context` explicitly, in which case attempting
/// to pick up the task-local context is prevented. This can be useful when we know that
/// we're about to start a top-level span, or if a span should be started from a different,
/// stored away previously,
///
/// - Warning: You MUST NOT ``Span/end()`` the span explicitly, because at the end of the `withSpan`
///   operation closure returning the span will be closed automatically.
///
/// - Parameters:
///   - operationName: The name of the operation being traced. This may be a handler function, a database call, and so on.
///   - instant: The time instant at which the span started.
///   - context: The `ServiceContext` that provides information on where to start the span.
///   - kind: The kind of span.
///   - function: The function name in which the span was started
///   - fileID: The `fileID` where the span was started.
///   - line: The file line where the span was started.
///   - operation: The operation that this span measures.
/// - Returns: the value returned by `operation`.
/// - Throws: the error the `operation` throws (if any).
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
public func withSpan<T, Instant: TracerInstant>(
    _ operationName: String,
    at instant: @autoclosure () -> Instant,
    context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
    ofKind kind: SpanKind = .internal,
    function: String = #function,
    file fileID: String = #fileID,
    line: UInt = #line,
    _ operation: (any Span) throws -> T
) rethrows -> T {
    try InstrumentationSystem.legacyTracer.withAnySpan(
        operationName,
        at: instant(),
        context: context(),
        ofKind: kind,
        function: function,
        file: fileID,
        line: line
    ) { anySpan in
        try operation(anySpan)
    }
}

/// Start a new span and automatically end when the operation completes,
/// including recording the error in case the operation throws.
///
/// The current task-local `ServiceContext` is picked up and provided to the underlying tracer.
/// It is also possible to pass a specific `context` explicitly, in which case attempting
/// to pick up the task-local context is prevented. This can be useful when we know that
/// we're about to start a top-level span, or if a span should be started from a different,
/// stored away previously,
///
/// - Warning: You MUST NOT ``Span/end()`` the span explicitly, because at the end of the `withSpan`
///   operation closure returning the span will be closed automatically.
///
/// - Parameters:
///   - operationName: The name of the operation being traced. This may be a handler function, a database call, and so on.
///   - context: The `ServiceContext` that provides information on where to start the span.
///   - kind: The kind of span.
///   - function: The function name in which the span was started.
///   - fileID: The `fileID` where the span was started.
///   - line: The file line where the span was started.
///   - operation: The operation that this span measures.
/// - Returns: the value returned by `operation`.
/// - Throws: the error the `operation` throws (if any).
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
public func withSpan<T>(
    _ operationName: String,
    context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
    ofKind kind: SpanKind = .internal,
    function: String = #function,
    file fileID: String = #fileID,
    line: UInt = #line,
    _ operation: (any Span) throws -> T
) rethrows -> T {
    try InstrumentationSystem.legacyTracer.withAnySpan(
        operationName,
        at: DefaultTracerClock.now,
        context: context(),
        ofKind: kind,
        function: function,
        file: fileID,
        line: line
    ) { anySpan in
        try operation(anySpan)
    }
}

/// Start a new span and automatically end when the operation completes,
/// including recording the error in case the operation throws.
///
/// The current task-local `ServiceContext` is picked up and provided to the underlying tracer.
/// It is also possible to pass a specific `context` explicitly, in which case attempting
/// to pick up the task-local context is prevented. This can be useful when we know that
/// we're about to start a top-level span, or if a span should be started from a different,
/// stored away previously,
///
/// - Warning: You MUST NOT ``Span/end()`` the span explicitly, because at the end of the `withSpan`
///   operation closure returning the span will be closed automatically.
///
/// - Parameters:
///   - operationName: The name of the operation being traced. This may be a handler function, a database call, and so on.
///   - context: The `ServiceContext` that provides information on where to start the span.
///   - kind: The kind of span.
///   - instant: The time instant at which the span started.
///   - function: The function name in which the span was started.
///   - fileID: The `fileID` where the span was started.
///   - line: The file line where the span was started.
///   - operation: The operation that this span measures.
/// - Returns: the value returned by `operation`.
/// - Throws: the error the `operation` throws (if any).
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public func withSpan<T>(
    _ operationName: String,
    context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
    ofKind kind: SpanKind = .internal,
    at instant: @autoclosure () -> some TracerInstant = DefaultTracerClock.now,
    function: String = #function,
    file fileID: String = #fileID,
    line: UInt = #line,
    _ operation: (any Span) throws -> T
) rethrows -> T {
    try InstrumentationSystem.legacyTracer.withAnySpan(
        operationName,
        at: instant(),
        context: context(),
        ofKind: kind,
        function: function,
        file: fileID,
        line: line
    ) { anySpan in
        try operation(anySpan)
    }
}

// ==== withSpan + async --------------------------------------------------

/// Start a new span and automatically end when the operation completes,
/// including recording the error in case the operation throws.
///
/// The current task-local `ServiceContext` is picked up and provided to the underlying tracer.
/// It is also possible to pass a specific `context` explicitly, in which case attempting
/// to pick up the task-local context is prevented. This can be useful when we know that
/// we're about to start a top-level span, or if a span should be started from a different,
/// stored away previously,
///
/// - Warning: You MUST NOT ``Span/end()`` the span explicitly, because at the end of the `withSpan`
///   operation closure returning the span will be closed automatically.
///
/// - Parameters:
///   - operationName: The name of the operation being traced. This may be a handler function, a database call, and so on.
///   - instant: The time instant at which the span started.
///   - context: The `ServiceContext` providing information on where to start the new ``Span``.
///   - kind: The ``SpanKind`` of the new ``Span``.
///   - isolation: Defaulted parameter for inheriting isolation of calling actor.
///   - function: The function name in which the span was started.
///   - fileID: The `fileID` where the span was started.
///   - line: The file line where the span was started.
///   - operation: The operation that this span measures.
/// - Returns: the value returned by `operation`.
/// - Throws: the error the `operation` throws (if any).
#if compiler(>=6.0)
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
public func withSpan<T, Instant: TracerInstant>(
    _ operationName: String,
    at instant: @autoclosure () -> Instant,
    context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
    ofKind kind: SpanKind = .internal,
    isolation: isolated (any Actor)? = #isolation,
    function: String = #function,
    file fileID: String = #fileID,
    line: UInt = #line,
    _ operation: (any Span) async throws -> T
) async rethrows -> T {
    try await InstrumentationSystem.legacyTracer.withAnySpan(
        operationName,
        at: instant(),
        context: context(),
        ofKind: kind,
        function: function,
        file: fileID,
        line: line
    ) { anySpan in
        try await operation(anySpan)
    }
}
#endif

#if compiler(>=6.0)
@_disfavoredOverload @available(*, deprecated, message: "Prefer #isolation version of this API")
#endif
/// Start a new span and automatically end when the operation completes,
/// including recording the error in case the operation throws.
///
/// - Parameters:
///   - operationName: The name of the operation being traced. This may be a handler function, a database call, and so on.
///   - instant: The time instant at which the span started.
///   - context: The `ServiceContext` providing information on where to start the new ``Span``.
///   - kind: The ``SpanKind`` of the new ``Span``.
///   - isolation: Defaulted parameter for inheriting isolation of calling actor.
///   - function: The function name in which the span was started.
///   - fileID: The `fileID` where the span was started.
///   - line: The file line where the span was started.
///   - operation: The operation that this span measures.
/// - Returns: the value returned by `operation`.
/// - Throws: the error the `operation` throws (if any).
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
public func withSpan<T, Instant: TracerInstant>(
    _ operationName: String,
    at instant: @autoclosure () -> Instant,
    context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
    ofKind kind: SpanKind = .internal,
    function: String = #function,
    file fileID: String = #fileID,
    line: UInt = #line,
    _ operation: (any Span) async throws -> T
) async rethrows -> T {
    try await InstrumentationSystem.legacyTracer.withAnySpan(
        operationName,
        at: instant(),
        context: context(),
        ofKind: kind,
        function: function,
        file: fileID,
        line: line
    ) { anySpan in
        try await operation(anySpan)
    }
}

/// Start a new span and automatically end when the operation completes,
/// including recording the error in case the operation throws.
///
/// The current task-local `ServiceContext` is picked up and provided to the underlying tracer.
/// It is also possible to pass a specific `context` explicitly, in which case attempting
/// to pick up the task-local context is prevented. This can be useful when we know that
/// we're about to start a top-level span, or if a span should be started from a different,
/// stored away previously,
///
/// - Warning: You MUST NOT ``Span/end()`` the span explicitly, because at the end of the `withSpan`
///   operation closure returning the span will be closed automatically.
///
/// - Parameters:
///   - operationName: The name of the operation being traced. This may be a handler function, a database call, and so on.
///   - context: The `ServiceContext` providing information on where to start the new ``Span``.
///   - kind: The ``SpanKind`` of the new ``Span``.
///   - isolation: Defaulted parameter for inheriting isolation of calling actor.
///   - function: The function name in which the span was started
///   - fileID: The `fileID` where the span was started.
///   - line: The file line where the span was started.
///   - operation: The operation that this span measures.
/// - Returns: the value returned by `operation`.
/// - Throws: the error the `operation` throws (if any).
#if compiler(>=6.0)
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
public func withSpan<T>(
    _ operationName: String,
    context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
    ofKind kind: SpanKind = .internal,
    isolation: isolated (any Actor)? = #isolation,
    function: String = #function,
    file fileID: String = #fileID,
    line: UInt = #line,
    _ operation: (any Span) async throws -> T
) async rethrows -> T {
    try await InstrumentationSystem.legacyTracer.withAnySpan(
        operationName,
        at: DefaultTracerClock.now,
        context: context(),
        ofKind: kind,
        function: function,
        file: fileID,
        line: line
    ) { anySpan in
        try await operation(anySpan)
    }
}
#endif

#if compiler(>=6.0)
@_disfavoredOverload @available(*, deprecated, message: "Prefer #isolation version of this API")
#endif
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
/// Start a new span and automatically end when the operation completes,
/// including recording the error in case the operation throws.
///
/// - Parameters:
///   - operationName: The name of the operation being traced. This may be a handler function, a database call, and so on.
///   - context: The `ServiceContext` providing information on where to start the new ``Span``.
///   - kind: The ``SpanKind`` of the new ``Span``.
///   - function: The function name in which the span was started
///   - fileID: The `fileID` where the span was started.
///   - line: The file line where the span was started.
///   - operation: The operation that this span measures.
/// - Returns: the value returned by `operation`.
/// - Throws: the error the `operation` throws (if any).
public func withSpan<T>(
    _ operationName: String,
    context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
    ofKind kind: SpanKind = .internal,
    function: String = #function,
    file fileID: String = #fileID,
    line: UInt = #line,
    _ operation: (any Span) async throws -> T
) async rethrows -> T {
    try await InstrumentationSystem.legacyTracer.withAnySpan(
        operationName,
        at: DefaultTracerClock.now,
        context: context(),
        ofKind: kind,
        function: function,
        file: fileID,
        line: line
    ) { anySpan in
        try await operation(anySpan)
    }
}

/// Start a new span and automatically end when the operation completes,
/// including recording the error in case the operation throws.
///
/// The current task-local `ServiceContext` is picked up and provided to the underlying tracer.
/// It is also possible to pass a specific `context` explicitly, in which case attempting
/// to pick up the task-local context is prevented. This can be useful when we know that
/// we're about to start a top-level span, or if a span should be started from a different,
/// stored away previously,
///
/// - Warning: You MUST NOT ``Span/end()`` the span explicitly, because at the end of the `withSpan`
///   operation closure returning the span will be closed automatically.
///
/// - Parameters:
///   - operationName: The name of the operation being traced. This may be a handler function, a database call, and so on.
///   - context: The `ServiceContext` providing information on where to start the new ``Span``.
///   - kind: The ``SpanKind`` of the new ``Span``.
///   - instant: The time instant at which the span started.
///   - isolation: Defaulted parameter for inheriting isolation of calling actor.
///   - function: The function name in which the span was started
///   - fileID: The `fileID` where the span was started.
///   - line: The file line where the span was started.
///   - operation: The operation that this span should be measuring
/// - Returns: the value returned by `operation`
/// - Throws: the error the `operation` has thrown (if any)
#if compiler(>=6.0)
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public func withSpan<T>(
    _ operationName: String,
    context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
    ofKind kind: SpanKind = .internal,
    at instant: @autoclosure () -> some TracerInstant = DefaultTracerClock.now,
    isolation: isolated (any Actor)? = #isolation,
    function: String = #function,
    file fileID: String = #fileID,
    line: UInt = #line,
    _ operation: (any Span) async throws -> T
) async rethrows -> T {
    try await InstrumentationSystem.legacyTracer.withAnySpan(
        operationName,
        at: instant(),
        context: context(),
        ofKind: kind,
        function: function,
        file: fileID,
        line: line
    ) { anySpan in
        try await operation(anySpan)
    }
}
#endif

#if compiler(>=6.0)
@_disfavoredOverload @available(*, deprecated, message: "Prefer #isolation version of this API")
#endif
/// Start a new span and automatically end when the operation completes,
/// including recording the error in case the operation throws.
///
/// - Parameters:
///   - operationName: The name of the operation being traced. This may be a handler function, a database call, and so on.
///   - context: The `ServiceContext` providing information on where to start the new ``Span``.
///   - kind: The ``SpanKind`` of the new ``Span``.
///   - instant: The time instant at which the span started.
///   - function: The function name in which the span was started.
///   - fileID: The `fileID` where the span was started.
///   - line: The file line where the span was started.
///   - operation: The operation that this span measures.
/// - Returns: the value returned by `operation`.
/// - Throws: the error the `operation` throws (if any).
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public func withSpan<T>(
    _ operationName: String,
    context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
    ofKind kind: SpanKind = .internal,
    at instant: @autoclosure () -> some TracerInstant = DefaultTracerClock.now,
    function: String = #function,
    file fileID: String = #fileID,
    line: UInt = #line,
    _ operation: (any Span) async throws -> T
) async rethrows -> T {
    try await InstrumentationSystem.legacyTracer.withAnySpan(
        operationName,
        at: instant(),
        context: context(),
        ofKind: kind,
        function: function,
        file: fileID,
        line: line
    ) { anySpan in
        try await operation(anySpan)
    }
}
