//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_exported import Baggage
import Dispatch
@_exported import Instrumentation

/// An `Instrument` with added functionality for distributed tracing. Is uses the span-based tracing model and is
/// based on the OpenTracing/OpenTelemetry spec.
public protocol Tracer: Instrument {
    /// Start a new `Span` with the given `Baggage` at a given time.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - baggage: The `Baggage` providing information on where to start the new `Span`.
    ///   - kind: The `SpanKind` of the new `Span`.
    ///   - time: The `DispatchTime` at which to start the new `Span`.
    func startSpan(
        _ operationName: String,
        baggage: Baggage,
        ofKind kind: SpanKind,
        at time: DispatchWallTime
    ) -> Span

    /// Export all ended spans to the configured backend that have not yet been exported.
    ///
    /// This function should only be called in cases where it is absolutely necessary,
    /// such as when using some FaaS providers that may suspend the process after an invocation, but before the backend exports the completed spans.
    ///
    /// This function should not block indefinitely, implementations should offer a configurable timeout for flush operations.
    func forceFlush()
}

extension Tracer {
    /// Start a new `Span` with the given `Baggage` starting at `DispatchWallTime.now()`.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - baggage: Baggage potentially containing trace identifiers of a parent `Span`.
    ///   - kind: The `SpanKind` of the `Span` to be created. Defaults to `.internal`.
    public func startSpan(
        _ operationName: String,
        baggage: Baggage,
        ofKind kind: SpanKind = .internal
    ) -> Span {
        return self.startSpan(operationName, baggage: baggage, ofKind: kind, at: .now())
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Span creation: with `LoggingContext`

extension Tracer {
    /// Start a new `Span` with the given `Baggage` starting at `DispatchWallTime.now()`.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - context: Logging context containing a `Baggage` which may contain trace identifiers of a parent `Span`.
    ///   - kind: The `SpanKind` of the `Span` to be created. Defaults to `.internal`.
    public func startSpan(
        _ operationName: String,
        context: LoggingContext,
        ofKind kind: SpanKind = .internal
    ) -> Span {
        return self.startSpan(operationName, baggage: context.baggage, ofKind: kind, at: .now())
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Starting spans: `withSpan`

extension Tracer {
    /// Execute a specific task within a newly created `Span`.
    ///
    /// DO NOT `end()` the passed in span manually. It will be ended automatically when the `function` returns.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - context: Logging context containing a `Baggage` which may contain trace identifiers of a parent `Span`.
    ///   - kind: The `SpanKind` of the `Span` to be created. Defaults to `.internal`.
    ///   - function: function to wrap in a span start/end and execute immediately
    /// - Returns: the value returned by `function`
    /// - Throws: the error the `function` has thrown (if any)
    public func withSpan<T>(
        _ operationName: String,
        context: LoggingContext,
        ofKind kind: SpanKind = .internal,
        _ function: (Span) throws -> T
    ) rethrows -> T {
        let span = self.startSpan(operationName, context: context, ofKind: kind)
        do {
            return try function(span)
        } catch {
            span.recordError(error)
            span.end()
            throw error // rethrow
        }
    }

    /// Execute a specific task within a newly created `Span`.
    ///
    /// DO NOT `end()` the passed in span manually. It will be ended automatically when the `function` returns.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - baggage: Baggage potentially containing trace identifiers of a parent `Span`.
    ///   - kind: The `SpanKind` of the `Span` to be created. Defaults to `.internal`.
    ///   - function: function to wrap in a span start/end and execute immediately
    /// - Returns: the value returned by `function`
    /// - Throws: the error the `function` has thrown (if any)
    public func withSpan<T>(
        _ operationName: String,
        baggage: Baggage,
        ofKind kind: SpanKind = .internal,
        _ function: (Span) throws -> T
    ) rethrows -> T {
        let span = self.startSpan(operationName, baggage: baggage, ofKind: kind)
        do {
            return try function(span)
        } catch {
            span.recordError(error)
            span.end()
            throw error // rethrow
        }
    }
}
