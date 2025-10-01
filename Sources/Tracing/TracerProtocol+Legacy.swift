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

/// A tracer protocol that supports Swift 5.6.
///
/// **This protocol will be deprecated as soon as possible**, and the library will continue recommending Swift 5.7+
/// in order to make use of new language features that make expressing the tracing API free of existential types when not necessary.
///
/// When possible, prefer using ``Tracer`` and ``withSpan(_:context:ofKind:at:function:file:line:_:)-8gw3v`` APIs,
/// rather than these `startAnySpan` APIs which unconditionally always return existential Spans even when not necessary
/// (under Swift 5.7+ type-system enhancement wrt. protocols with associated types)..
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
@available(*, deprecated, renamed: "Tracer")
public protocol LegacyTracer: Instrument {
    /// Start a new span returning an existential span reference.
    ///
    /// - Warning: This method will be deprecated in favor of `Tracer/withSpan` as soon as this project is able to require Swift 5.7.
    ///
    /// The current task-local `ServiceContext` is picked up and provided to the underlying tracer.
    /// It is also possible to pass a specific `context` explicitly, in which case attempting
    /// to pick up the task-local context is prevented. This can be useful when we know that
    /// we're about to start a top-level span, or if a span should be started from a different,
    /// stored away previously,
    ///
    /// - Note: Legacy API, prefer using ``startSpan(_:context:ofKind:at:
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
    ///   - instant: the time instant at which the span started.
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
    @available(*, deprecated, message: "prefer withSpan")
    func startAnySpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> any Tracing.Span

    /// Export all ended spans to the configured backend that have not yet been exported.
    ///
    /// This function should only be called in cases where it is absolutely necessary,
    /// such as when using some FaaS providers that may suspend the process after an invocation, but before the backend exports the completed spans.
    ///
    /// This function should not block indefinitely, implementations should offer a configurable timeout for flush operations.
    @available(*, deprecated)
    func forceFlush()
}

// ==== ------------------------------------------------------------------
// MARK: Legacy implementations for Swift 5.7

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
extension LegacyTracer {
    // ==== startSpan ---------------------------------------------------------

    /// Start a new span returning an existential span reference.
    ///
    /// - Warning: This method will be deprecated in favor of `Tracer/withSpan` as soon as this project is able to require Swift 5.7.
    ///
    /// The current task-local `ServiceContext` is picked up and provided to the underlying tracer.
    /// It is also possible to pass a specific `context` explicitly, in which case attempting
    /// to pick up the task-local context is prevented. This can be useful when we know that
    /// we're about to start a top-level span, or if a span should be started from a different,
    /// stored away previously,
    ///
    /// - Note: Legacy API, prefer using ``startSpan(_:context:ofKind:at:
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
    ///   - instant: the time instant at which the span started.
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
    @available(*, deprecated, message: "prefer withSpan")
    public func startAnySpan<Instant: TracerInstant>(
        _ operationName: String,
        at instant: @autoclosure () -> Instant,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line
    ) -> any Tracing.Span {
        self.startAnySpan(
            operationName,
            context: context(),
            ofKind: kind,
            at: instant(),
            function: function,
            file: fileID,
            line: line
        )
    }

    /// Start a new span returning an existential span reference.
    ///
    /// - Warning: This method will be deprecated in favor of `Tracer/withSpan` as soon as this project is able to require Swift 5.7.
    ///
    ///
    /// The current task-local `ServiceContext` is picked up and provided to the underlying tracer.
    /// It is also possible to pass a specific `context` explicitly, in which case attempting
    /// to pick up the task-local context is prevented. This can be useful when we know that
    /// we're about to start a top-level span, or if a span should be started from a different,
    /// stored away previously,
    ///
    /// - Note: Legacy API, prefer using ``startSpan(_:context:ofKind:at:
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
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
    public func startAnySpan(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line
    ) -> any Tracing.Span {
        self.startAnySpan(
            operationName,
            context: context(),
            ofKind: kind,
            at: DefaultTracerClock.now,
            function: function,
            file: fileID,
            line: line
        )
    }

    // ==== withAnySpan + sync ------------------------------------------------

    /// Start a new ``Span`` and automatically end when the `operation` completes,
    /// including recording the `error` in case the operation throws.
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
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
    ///   - operation: The operation that this span measures.
    /// - Returns: the value returned by `operation`.
    /// - Throws: the error the `operation` throws (if any).
    public func withAnySpan<T, Instant: TracerInstant>(
        _ operationName: String,
        at instant: @autoclosure () -> Instant,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Tracing.Span) throws -> T
    ) rethrows -> T {
        let span = self.startAnySpan(
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
    /// - Warning: This method will be deprecated in favor of `Tracer/withSpan` as soon as this project is able to require Swift 5.7.
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
    public func withAnySpan<T>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Tracing.Span) throws -> T
    ) rethrows -> T {
        try self.withAnySpan(
            operationName,
            at: DefaultTracerClock.now,
            context: context(),
            ofKind: kind,
            function: function,
            file: fileID,
            line: line,
            operation
        )
    }

    // ==== withAnySpan async -------------------------------------------------

    /// Start a new span and automatically end when the operation completes,
    /// including recording the error in case the operation throws.
    ///
    /// - Warning: This method will be deprecated in favor of `Tracer/withSpan` as soon as this project is able to require Swift 5.7.
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
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
    ///   - operation: The operation that this span measures.
    /// - Returns: the value returned by `operation`.
    /// - Throws: the error the `operation` throws (if any).
    #if compiler(>=6.0)
    public func withAnySpan<T, Instant: TracerInstant>(
        _ operationName: String,
        at instant: @autoclosure () -> Instant,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        isolation: isolated (any Actor)? = #isolation,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Tracing.Span) async throws -> T
    ) async rethrows -> T {
        let span = self.startAnySpan(
            operationName,
            at: instant(),
            context: context(),
            ofKind: kind,
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
    /// Start a new span and automatically end when the operation completes,
    /// including recording the error in case the operation throws.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, a database call, and so on.
    ///   - instant: the time instant at which the span started.
    ///   - context: The `ServiceContext` providing information on where to start the new ``Span``.
    ///   - kind: The ``SpanKind`` of the new ``Span``.
    ///   - isolation: Defaulted parameter for inheriting isolation of calling actor.
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
    ///   - operation: The operation that this span measures.
    /// - Returns: the value returned by `operation`.
    /// - Throws: the error the `operation` throws (if any).
    public func withAnySpan<T, Instant: TracerInstant>(
        _ operationName: String,
        at instant: @autoclosure () -> Instant,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Tracing.Span) async throws -> T
    ) async rethrows -> T {
        let span = self.startAnySpan(
            operationName,
            at: instant(),
            context: context(),
            ofKind: kind,
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

    /// Start a new span and automatically end when the operation completes,
    /// including recording the error in case the operation throws.
    ///
    /// - Warning: This method will be deprecated in favor of `Tracer/withSpan` as soon as this project is able to require Swift 5.7.
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
    ///   - isolation: Defaulted parameter for inheriting isolation of calling actor.
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
    ///   - operation: The operation that this span measures.
    /// - Returns: the value returned by `operation`.
    /// - Throws: the error the `operation` throws (if any).
    #if compiler(>=6.0)
    public func withAnySpan<T>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        isolation: isolated (any Actor)? = #isolation,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Tracing.Span) async throws -> T
    ) async rethrows -> T {
        let span = self.startAnySpan(
            operationName,
            at: DefaultTracerClock.now,
            context: context(),
            ofKind: kind,
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
    /// Start a new span and automatically end when the operation completes,
    /// including recording the error in case the operation throws.
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
    public func withAnySpan<T>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Tracing.Span) async throws -> T
    ) async rethrows -> T {
        let span = self.startAnySpan(
            operationName,
            at: DefaultTracerClock.now,
            context: context(),
            ofKind: kind,
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

// Provide compatibility shims of the `...AnySpan` APIs
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Tracer {
    /// Start a new span returning an existential span reference.
    ///
    /// - Warning: This method will be deprecated in favor of `Tracer/withSpan` as soon as this project is able to require Swift 5.7.
    ///
    /// The current task-local `ServiceContext` is picked up and provided to the underlying tracer.
    /// It is also possible to pass a specific `context` explicitly, in which case attempting
    /// to pick up the task-local context is prevented. This can be useful when we know that
    /// we're about to start a top-level span, or if a span should be started from a different,
    /// stored away previously,
    ///
    /// - Note: Legacy API, prefer using ``startSpan(_:context:ofKind:at:
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
    ///   - instant: the time instant at which the span started.
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
    public func startAnySpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContextModule.ServiceContext,
        ofKind kind: Tracing.SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> Tracing.Span {
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

    /// Start a new span and automatically end when the operation completes,
    /// including recording the error in case the operation throws.
    ///
    /// - Warning: This method will be deprecated in favor of `Tracer/withSpan` as soon as this project is able to require Swift 5.7.
    ///
    /// The current task-local `ServiceContext` is picked up and provided to the underlying tracer.
    /// It is also possible to pass a specific `context` explicitly, in which case attempting
    /// to pick up the task-local context is prevented. This can be useful when we know that
    /// we're about to start a top-level span, or if a span should be started from a different,
    /// stored away previously,
    ///
    /// - Note: Legacy API, prefer using ``startSpan(_:context:ofKind:at:
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
    ///   - instant: the time instant at which the span started.
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
    ///   - operation: The operation that this span measures.
    /// - Returns: the value returned by `operation`.
    /// - Throws: the error the `operation` throws (if any).
    public func withAnySpan<T>(
        _ operationName: String,
        at instant: @autoclosure () -> some TracerInstant = DefaultTracerClock.now,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any Tracing.Span) throws -> T
    ) rethrows -> T {
        try self.withSpan(
            operationName,
            context: context(),
            ofKind: kind,
            at: instant(),
            function: function,
            file: fileID,
            line: line
        ) { span in
            try operation(span)
        }
    }

    /// Start a new span and automatically end when the operation completes,
    /// including recording the error in case the operation throws.
    ///
    /// - Warning: This method will be deprecated in favor of `Tracer/withSpan` as soon as this project is able to require Swift 5.7.
    ///
    /// The current task-local `ServiceContext` is picked up and provided to the underlying tracer.
    /// It is also possible to pass a specific `context` explicitly, in which case attempting
    /// to pick up the task-local context is prevented. This can be useful when we know that
    /// we're about to start a top-level span, or if a span should be started from a different,
    /// stored away previously,
    ///
    /// - Note: Legacy API, prefer using ``startSpan(_:context:ofKind:at:
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
    ///   - instant: the time instant at which the span started.
    ///   - isolation: Defaulted parameter for inheriting isolation of calling actor.
    ///   - function: The function name in which the span started.
    ///   - fileID: The `fileID` where the span started.
    ///   - line: The file line where the span started.
    ///   - operation: The operation that this span measures.
    /// - Returns: the value returned by `operation`.
    /// - Throws: the error the `operation` throws (if any).
    #if compiler(>=6.0)
    public func withAnySpan<T>(
        _ operationName: String,
        at instant: @autoclosure () -> some TracerInstant = DefaultTracerClock.now,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        isolation: isolated (any Actor)? = #isolation,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        @_inheritActorContext @_implicitSelfCapture _ operation: (any Tracing.Span) async throws -> T
    ) async rethrows -> T {
        try await self.withSpan(
            operationName,
            context: context(),
            ofKind: kind,
            at: instant(),
            function: function,
            file: fileID,
            line: line
        ) { span in
            try await operation(span)
        }
    }
    #endif

    #if compiler(>=6.0)
    // swift-format-ignore: Spacing // fights with formatter
    @_disfavoredOverload @available(*, deprecated, message: "Prefer #isolation version of this API")
    #endif
    /// Start a new span and automatically end when the operation completes,
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
    public func withAnySpan<T>(
        _ operationName: String,
        at instant: @autoclosure () -> some TracerInstant = DefaultTracerClock.now,
        context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        @_inheritActorContext @_implicitSelfCapture _ operation: (any Tracing.Span) async throws -> T
    ) async rethrows -> T {
        try await self.withSpan(
            operationName,
            context: context(),
            ofKind: kind,
            at: instant(),
            function: function,
            file: fileID,
            line: line
        ) { span in
            try await operation(span)
        }
    }
}
