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

/// Tracer that ignores all operations, used when no tracing is required.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
public struct NoOpTracer: LegacyTracer {

    /// The type used to represent a span.
    public typealias Span = NoOpSpan

    /// Creates a no-op tracer.
    public init() {}

    /// Start a new span using the global bootstrapped tracer implementation.
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - context: The `ServiceContext` providing information on where to start the new ``Span``.
    ///   - kind: The ``SpanKind`` of the new ``Span``.
    ///   - instant: the time instant at which the span started
    ///   - function: The function name in which the span was started
    ///   - fileID: The `fileID` where the span was started.
    ///   - line: The file line where the span was started.
    public func startAnySpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> any Tracing.Span {
        NoOpSpan(context: context())
    }

    /// Export all ended spans to the configured backend that have not yet been exported.
    ///
    /// This function should only be called in cases where it is absolutely necessary,
    /// such as when using some FaaS providers that may suspend the process after an invocation, but before the backend exports the completed spans.
    ///
    /// This function should not block indefinitely, implementations should offer a configurable timeout for flush operations.
    public func forceFlush() {}

    /// Extract values from a service context and inject them into the given carrier using the provided injector.
    ///
    /// - Parameters:
    ///   - context: The `ServiceContext` from which relevant information is extracted.
    ///   - carrier: The `Carrier` into which this information is injected.
    ///   - injector: The `Injector` to use to inject extracted `ServiceContext` into the given `Carrier`.
    public func inject<Carrier, Inject>(_ context: ServiceContext, into carrier: inout Carrier, using injector: Inject)
    where Inject: Injector, Carrier == Inject.Carrier {
        // no-op
    }

    /// Extract values from a carrier, using the given extractor, and inject them into the provided service context.
    ///
    /// - Parameters:
    ///   - carrier: The `Carrier` that was used to propagate values across boundaries.
    ///   - context: The `ServiceContext` into which these values should be injected.
    ///   - extractor: The `Extractor` that extracts values from the given `Carrier`.
    public func extract<Carrier, Extract>(
        _ carrier: Carrier,
        into context: inout ServiceContext,
        using extractor: Extract
    )
    where Extract: Extractor, Carrier == Extract.Carrier {
        // no-op
    }

    /// A span created by the no-op tracer.
    ///
    /// This span maintains its context, but does not record events, links, or errors and provides no attributes.
    public struct NoOpSpan: Tracing.Span {
        /// The service context of the span.
        public let context: ServiceContext
        /// A Boolean value that indicates whether the span is actively recording updates.
        public var isRecording: Bool {
            false
        }

        /// The operation name this span represents.
        public var operationName: String {
            get {
                "noop"
            }
            nonmutating set {
                // ignore
            }
        }

        /// Creates a new no-op span with the context you provide.
        /// - Parameter context: The service context.
        public init(context: ServiceContext) {
            self.context = context
        }
        /// Updates the status of the span to the value you provide.
        /// - Parameter status: The status to set.
        public func setStatus(_ status: SpanStatus) {}

        /// Adds a link to the span.
        /// - Parameter link: The link to add.
        public func addLink(_ link: SpanLink) {}

        /// Adds an event you provide to the span.
        /// - Parameter event: The event to record.
        public func addEvent(_ event: SpanEvent) {}

        /// Records an error to the span.
        /// - Parameters:
        ///   - error: The error to record.
        ///   - attributes: Span attributes associated with the error.
        ///   - instant: The time instant of the error.
        public func recordError<Instant: TracerInstant>(
            _ error: Error,
            attributes: SpanAttributes,
            at instant: @autoclosure () -> Instant
        ) {}

        /// The span attributes.
        public var attributes: SpanAttributes {
            get {
                [:]
            }
            nonmutating set {
                // ignore
            }
        }

        /// Finishes the span.
        /// - Parameter instant: the time instant the span completed.
        public func end<Instant: TracerInstant>(at instant: @autoclosure () -> Instant) {
            // ignore
        }
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension NoOpTracer: Tracer {
    /// Start a new span using the global bootstrapped tracer implementation.
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - context: The `ServiceContext` providing information on where to start the new ``Span``.
    ///   - kind: The ``SpanKind`` of the new ``Span``.
    ///   - instant: the time instant at which the span started
    ///   - function: The function name in which the span was started
    ///   - fileID: The `fileID` where the span was started.
    ///   - line: The file line where the span was started.
    public func startSpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> NoOpSpan {
        NoOpSpan(context: context())
    }
}
