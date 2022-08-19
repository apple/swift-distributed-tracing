//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2022 Apple Inc. and the Swift Distributed Tracing project
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

/// An `Instrument` with added functionality for distributed tracing. It uses the span-based tracing model and is
/// based on the OpenTracing/OpenTelemetry spec.
public protocol Tracer: Instrument {
    /// Start a new ``Span`` with the given `Baggage` at a given time.
    ///
    /// - Note: Prefer to use `withSpan` to start a span as it automatically takes care of ending the span,
    /// and recording errors when thrown. Use `startSpan` iff you need to pass the span manually to a different
    /// location in your source code to end it.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - baggage: The `Baggage` providing information on where to start the new ``Span``.
    ///   - kind: The ``SpanKind`` of the new ``Span``.
    ///   - time: The `DispatchTime` at which to start the new ``Span``.
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
    /// Start a new ``Span`` with the given `Baggage` starting at `DispatchWallTime.now()`.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - baggage: Baggage potentially containing trace identifiers of a parent ``Span``.
    ///   - kind: The ``SpanKind`` of the ``Span`` to be created. Defaults to ``SpanKind/internal``.
    public func startSpan(
        _ operationName: String,
        baggage: Baggage,
        ofKind kind: SpanKind = .internal
    ) -> Span {
        self.startSpan(operationName, baggage: baggage, ofKind: kind, at: .now())
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Starting spans: `withSpan`

extension Tracer {
    /// Execute a specific task within a newly created ``Span``.
    ///
    /// DO NOT `end()` the passed in span manually. It will be ended automatically when the `operation` returns.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - baggage: Baggage potentially containing trace identifiers of a parent ``Span``.
    ///   - kind: The ``SpanKind`` of the ``Span`` to be created. Defaults to ``SpanKind/internal``.
    ///   - operation: operation to wrap in a span start/end and execute immediately
    /// - Returns: the value returned by `operation`
    /// - Throws: the error the `operation` has thrown (if any)
    public func withSpan<T>(
        _ operationName: String,
        baggage: Baggage,
        ofKind kind: SpanKind = .internal,
        _ operation: (Span) throws -> T
    ) rethrows -> T {
        let span = self.startSpan(operationName, baggage: baggage, ofKind: kind)
        defer { span.end() }
        do {
            return try operation(span)
        } catch {
            span.recordError(error)
            throw error // rethrow
        }
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Starting spans: Task-local Baggage propagation

#if swift(>=5.5) && canImport(_Concurrency)
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Tracer {
    /// Execute the given operation within a newly created ``Span``,
    /// started as a child of the currently stored task local `Baggage.current` or as a root span if `nil`.
    ///
    /// DO NOT `end()` the passed in span manually. It will be ended automatically when the `operation` returns.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - kind: The ``SpanKind`` of the ``Span`` to be created. Defaults to ``SpanKind/internal``.
    ///   - operation: operation to wrap in a span start/end and execute immediately
    /// - Returns: the value returned by `operation`
    /// - Throws: the error the `operation` has thrown (if any)
    public func withSpan<T>(
        _ operationName: String,
        ofKind kind: SpanKind = .internal,
        _ operation: (Span) throws -> T
    ) rethrows -> T {
        try self.withSpan(operationName, baggage: .current ?? .topLevel, ofKind: kind) { span in
            try Baggage.$current.withValue(span.baggage) {
                try operation(span)
            }
        }
    }

    /// Execute the given async operation within a newly created ``Span``,
    /// started as a child of the currently stored task local `Baggage.current` or as a root span if `nil`.
    ///
    /// DO NOT `end()` the passed in span manually. It will be ended automatically when the `operation` returns.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - kind: The ``SpanKind`` of the ``Span`` to be created. Defaults to ``SpanKind/internal``.
    ///   - operation: operation to wrap in a span start/end and execute immediately
    /// - Returns: the value returned by `operation`
    /// - Throws: the error the `operation` has thrown (if any)
    public func withSpan<T>(
        _ operationName: String,
        ofKind kind: SpanKind = .internal,
        _ operation: (Span) async throws -> T
    ) async rethrows -> T {
        let span = self.startSpan(operationName, baggage: .current ?? .topLevel, ofKind: kind)
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

    /// Execute the given async operation within a newly created `Span`,
    /// started as a child of the passed in `Baggage` or as a root span if `nil`.
    ///
    /// DO NOT `end()` the passed in span manually. It will be ended automatically when the `operation` returns.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - baggage: The baggage to be used for the newly created span. It may be obtained by the user manually from the `Baggage.current`,
    //               task local and modified before passing into this function. The baggage will be made the current task-local baggage for the duration of the `operation`.
    ///   - kind: The `SpanKind` of the `Span` to be created. Defaults to `.internal`.
    ///   - operation: operation to wrap in a span start/end and execute immediately
    /// - Returns: the value returned by `operation`
    /// - Throws: the error the `operation` has thrown (if any)
    public func withSpan<T>(
        _ operationName: String,
        baggage: Baggage,
        ofKind kind: SpanKind = .internal,
        _ operation: (Span) async throws -> T
    ) async rethrows -> T {
        let span = self.startSpan(operationName, baggage: baggage, ofKind: kind)
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
#endif
