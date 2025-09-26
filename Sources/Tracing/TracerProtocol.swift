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

// ==== -----------------------------------------------------------------------
// MARK: Tracer protocol

/// A tracer capable of creating new trace spans.
///
/// A tracer is a special kind of instrument with the added ability to start a ``Span``.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
public protocol Tracer: LegacyTracer {
    /// The concrete type of span this tracer produces.
    associatedtype Span: Tracing.Span

    /// Start a new span with the given service context.
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
    ///   - context: The `ServiceContext` providing information on where to start the new ``Span``.
    ///   - kind: The ``SpanKind`` of the new ``Span``.
    ///   - instant: The time instant at which the span started.
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
    func startSpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> Self.Span

    /// Retrieve the active span for the given service context.
    ///
    /// - Note: This API does not enable look up of completed spans.
    /// It was added retroactively with a default implementation returning `nil` and therefore isn't guaranteed to be implemented by all Tracers.
    /// - Parameter context: The context containing information that uniquely identifies the span being obtained.
    /// - Returns: The span identified by the given `ServiceContext` in case it's still recording.
    func activeSpan(identifiedBy context: ServiceContext) -> Span?
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
extension Tracer {
    /// Start a new span with the current, or the explicitly passed, service context.
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
    ///   - context: The `ServiceContext` providing information on where to start the new ``Span``.
    ///   - kind: The ``SpanKind`` of the new ``Span``.
    ///   - instant: The time instant at which the span started.
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
    public func startSpan(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        at instant: @autoclosure () -> some TracerInstant = DefaultTracerClock.now,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line
    ) -> Self.Span {
        self.startSpan(
            operationName,
            context: context(),
            ofKind: kind,
            at: instant(),
            function: function,
            file: fileID,
            line: line
        )
    }

    /// Default implementation that always returns `nil`.
    ///
    /// This default exists in order to facilitate source-compatible introduction of the ``activeSpan(identifiedBy:)`` protocol requirement.
    ///
    /// - Parameter context: The context containing information that uniquely identifies the span being obtained.
    /// - Returns: `nil`.
    public func activeSpan(identifiedBy context: ServiceContext) -> Span? {
        nil
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Starting spans: `withSpan`

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Tracer {
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
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
    ///   - operation: The operation that this span measures.
    /// - Returns: the value returned by `operation`.
    /// - Throws: the error the `operation` throws (if any).
    public func withSpan<T>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        at instant: @autoclosure () -> some TracerInstant = DefaultTracerClock.now,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (Self.Span) throws -> T
    ) rethrows -> T {
        let span = self.startSpan(
            operationName,
            context: context(),
            ofKind: kind,
            at: instant(),
            function: function,
            file: fileID,
            line: line
        )
        defer { span.end() }
        do {
            return try ServiceContext.$current.withValue(span.context) {
                try operation(span)
            }
        } catch {
            span.recordError(error)
            throw error  // rethrow
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
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
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
        _ operation: (Self.Span) throws -> T
    ) rethrows -> T {
        let span = self.startSpan(
            operationName,
            context: context(),
            ofKind: kind,
            at: DefaultTracerClock.now,
            function: function,
            file: fileID,
            line: line
        )
        defer { span.end() }
        do {
            return try ServiceContext.$current.withValue(span.context) {
                try operation(span)
            }
        } catch {
            span.recordError(error)
            throw error  // rethrow
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
    ///   - instant: the time instant at which the span started.
    ///   - isolation: Defaulted parameter for inheriting isolation of calling actor.
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
    ///   - operation: The operation that this span measures.
    /// - Returns: the value returned by `operation`.
    /// - Throws: the error the `operation` throws (if any).
    #if compiler(>=6.0)
    public func withSpan<T>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        isolation: isolated (any Actor)? = #isolation,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        @_inheritActorContext @_implicitSelfCapture _ operation: (Self.Span) async throws -> T
    ) async rethrows -> T {
        let span = self.startSpan(
            operationName,
            context: context(),
            ofKind: kind,
            at: DefaultTracerClock.now,
            function: function,
            file: fileID,
            line: line
        )
        defer { span.end() }
        do {
            return try await ServiceContext.$current.withValue(span.context) {
                try await operation(span)
            }
        } catch {
            span.recordError(error)
            throw error  // rethrow
        }
    }
    #endif

    #if compiler(>=6.0)
    // swift-format-ignore: Spacing // fights with formatter
    @_disfavoredOverload @available(*, deprecated, message: "Prefer #isolation version of this API")
    #endif
    public func withSpan<T>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        @_inheritActorContext @_implicitSelfCapture _ operation: (Self.Span) async throws -> T
    ) async rethrows -> T {
        let span = self.startSpan(
            operationName,
            context: context(),
            ofKind: kind,
            at: DefaultTracerClock.now,
            function: function,
            file: fileID,
            line: line
        )
        defer { span.end() }
        do {
            return try await ServiceContext.$current.withValue(span.context) {
                try await operation(span)
            }
        } catch {
            span.recordError(error)
            throw error  // rethrow
        }
    }

    /// Start a new span and automatically end it when the operation completes,
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
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, a database call, and so on.
    ///   - context: The `ServiceContext` providing information on where to start the new ``Span``.
    ///   - kind: The ``SpanKind`` of the new ``Span``.
    ///   - instant: the time instant at which the span started.
    ///   - isolation: Defaulted parameter for inheriting isolation of calling actor.
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
    ///   - operation: The operation that this span measures.
    /// - Returns: the value returned by `operation`.
    /// - Throws: the error the `operation` throws (if any).
    #if compiler(>=6.0)
    public func withSpan<T>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        at instant: @autoclosure () -> some TracerInstant = DefaultTracerClock.now,
        isolation: isolated (any Actor)? = #isolation,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        @_inheritActorContext @_implicitSelfCapture _ operation: (Self.Span) async throws -> T
    ) async rethrows -> T {
        let span = self.startSpan(
            operationName,
            context: context(),
            ofKind: kind,
            at: instant(),
            function: function,
            file: fileID,
            line: line
        )
        defer { span.end() }
        do {
            return try await ServiceContext.$current.withValue(span.context) {
                try await operation(span)
            }
        } catch {
            span.recordError(error)
            throw error  // rethrow
        }
    }
    #endif

    #if compiler(>=6.0)
    // swift-format-ignore: Spacing // fights with formatter
    @_disfavoredOverload @available(*, deprecated, message: "Prefer #isolation version of this API")
    #endif
    /// Start a new span and automatically end it when the operation completes,
    /// including recording the error in case the operation throws.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, a database call, and so on.
    ///   - context: The `ServiceContext` providing information on where to start the new ``Span``.
    ///   - kind: The ``SpanKind`` of the new ``Span``.
    ///   - instant: the time instant at which the span started.
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
    ///   - operation: The operation that this span measures.
    /// - Returns: the value returned by `operation`.
    /// - Throws: the error the `operation` throws (if any).
    public func withSpan<T>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        at instant: @autoclosure () -> some TracerInstant = DefaultTracerClock.now,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        @_inheritActorContext @_implicitSelfCapture _ operation: (Self.Span) async throws -> T
    ) async rethrows -> T {
        let span = self.startSpan(
            operationName,
            context: context(),
            ofKind: kind,
            at: instant(),
            function: function,
            file: fileID,
            line: line
        )
        defer { span.end() }
        do {
            return try await ServiceContext.$current.withValue(span.context) {
                try await operation(span)
            }
        } catch {
            span.recordError(error)
            throw error  // rethrow
        }
    }
}
