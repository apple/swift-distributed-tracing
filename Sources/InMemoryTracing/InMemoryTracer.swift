//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_spi(Locking) import Instrumentation
import Tracing

/// An in-memory implementation of the `Tracer` protocol which can be used either in testing,
/// or in collecting and interrogating traces within a process, and acting on them programatically.
///
/// ### Span lifecycle
/// This tracer does _not_ automatically remove spans once they end.
/// In-memory tracer retains finished spans and makes them available for inspection through the `finishedSpans` property.
/// Spans that started but have not yet called `Span/end()` are available for inspection through the ``activeSpans`` property.
///
/// The `InMemoryTracer` retains spans until they are explicitly removed, for example by using
/// ``popFinishedSpans()`` or any of the `clear...` methods (such as ``clearFinishedSpans()``)
public struct InMemoryTracer: Tracer {

    public let idGenerator: IDGenerator

    public let recordInjections: Bool
    public let recordExtractions: Bool

    struct State {
        var activeSpans: [InMemorySpanContext: InMemorySpan] = [:]
        var finishedSpans: [FinishedInMemorySpan] = []
        var numberOfForceFlushes: Int = 0

        var injections: [Injection] = []
        var extractions: [Extraction] = []
    }
    var _state = LockedValueBox<State>(.init())

    /// Create a new ``InMemoryTracer``.
    ///
    /// - Parameters:
    ///   - idGenerator: strategy for generating trace and span identifiers
    ///   - recordInjections: A Boolean value that indicates whether the tracer records injected values.
    ///   - recordExtractions: A Boolean value that indicates whether the tracer records extracted values.
    public init(
        idGenerator: IDGenerator = .incrementing,
        recordInjections: Bool = true,
        recordExtractions: Bool = true
    ) {
        self.idGenerator = idGenerator
        self.recordInjections = recordInjections
        self.recordExtractions = recordExtractions
    }
}

// MARK: - Tracer

extension InMemoryTracer {

    /// Start a new span and automatically end it when the operation completes, including recording the error when the operation throws.
    /// - Parameters:
    ///   - operationName: The name of the operation being traced.
    ///   - context: The service context that provides information on where to start the new span.
    ///   - kind: The kind of span.
    ///   - instant: The time instant at which the span started.
    ///   - function: The function name in which the span was started.
    ///   - fileID: The fileID where the span was started.
    ///   - line: The file line where the span was started.
    /// - Returns: An in-memory span.
    public func startSpan<Instant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> InMemorySpan where Instant: TracerInstant {
        let parentContext = context()
        let spanContext: InMemorySpanContext

        if let parentSpanContext = parentContext.inMemorySpanContext {
            // child span
            spanContext = InMemorySpanContext(
                traceID: parentSpanContext.traceID,
                spanID: idGenerator.nextSpanID(),
                parentSpanID: parentSpanContext.spanID
            )
        } else {
            // root span
            spanContext = InMemorySpanContext(
                traceID: idGenerator.nextTraceID(),
                spanID: idGenerator.nextSpanID(),
                parentSpanID: nil
            )
        }

        var context = parentContext
        context.inMemorySpanContext = spanContext

        let span = InMemorySpan(
            operationName: operationName,
            context: context,
            spanContext: spanContext,
            kind: kind,
            startInstant: instant()
        ) { finishedSpan in
            _state.withValue {
                $0.activeSpans[spanContext] = nil
                $0.finishedSpans.append(finishedSpan)
            }
        }
        _state.withValue { $0.activeSpans[spanContext] = span }
        return span
    }

    /// Records a request to flush spans.
    public func forceFlush() {
        _state.withValue { $0.numberOfForceFlushes += 1 }
    }
}

// MARK: - InMemoryTracer querying

extension InMemoryTracer {

    /// An array of active spans
    ///
    /// For example, spans which have been started but have not yet finished (by calling `Span/end()`).
    public var activeSpans: [InMemorySpan] {
        _state.withValue { Array($0.activeSpans.values) }
    }

    /// Retrives a specific _active_ span, identified by the service context you provide.
    ///
    /// The service context provides the span, trace, and parent IDs
    /// stored in the `inMemorySpanContext`
    public func activeSpan(identifiedBy context: ServiceContext) -> InMemorySpan? {
        guard let spanContext = context.inMemorySpanContext else { return nil }
        return _state.withValue { $0.activeSpans[spanContext] }
    }

    /// The number of times forced flushes were requested.
    ///
    /// The number of times that `Tracer/forceFlush()` was called on this tracer.
    public var numberOfForceFlushes: Int {
        _state.withValue { $0.numberOfForceFlushes }
    }

    /// Retrieves, without removing, all the finished spans recorded by this tracer.
    ///
    /// - SeeAlso: `popFinishedSpans()`
    public var finishedSpans: [FinishedInMemorySpan] {
        _state.withValue { $0.finishedSpans }
    }

    /// Returns, and removes, all finished spans recorded by this tracer.
    public func popFinishedSpans() -> [FinishedInMemorySpan] {
        _state.withValue { state in
            defer { state.finishedSpans = [] }
            return state.finishedSpans
        }
    }

    /// Atomically clears the in-memory collection of finished spans in this tracer.
    public func clearFinishedSpans() {
        _state.withValue { $0.finishedSpans = [] }
    }

    /// Clears all registered finished spans, as well as injections/extractions performed by this tracer.
    public func clearAll(includingActive: Bool = false) {
        _state.withValue {
            $0.finishedSpans = []
            $0.injections = []
            $0.extractions = []
            if includingActive {
                $0.activeSpans = [:]
            }
        }
    }
}

// MARK: - Instrument

extension InMemoryTracer {

    /// The trace ID key for the in-memory tracer.
    public static let traceIDKey = "in-memory-trace-id"
    /// The span ID key for the in-memory tracer.
    public static let spanIDKey = "in-memory-span-id"

    /// Collects the service context you provide and inserts it into tracing carrier.
    /// - Parameters:
    ///   - context: The service context to add.
    ///   - carrier: The service implementation into which to add the service context.
    ///   - injector: The type that transfers service context into a carrier.
    public func inject<Carrier, Inject: Injector>(
        _ context: ServiceContext,
        into carrier: inout Carrier,
        using injector: Inject
    ) where Carrier == Inject.Carrier {
        var values = [String: String]()

        if let spanContext = context.inMemorySpanContext {
            injector.inject(spanContext.traceID, forKey: Self.traceIDKey, into: &carrier)
            values[Self.traceIDKey] = spanContext.traceID
            injector.inject(spanContext.spanID, forKey: Self.spanIDKey, into: &carrier)
            values[Self.spanIDKey] = spanContext.spanID
        }

        if recordInjections {
            let injection = Injection(context: context, values: values)
            _state.withValue { $0.injections.append(injection) }
        }
    }

    /// Lists all recorded calls to this tracer's inject method.
    ///
    /// Records calls to`Instrument/inject(_:into:using:)`.
    /// This may be used to inspect what span identifiers are being propagated by this tracer.
    public var performedContextInjections: [Injection] {
        _state.withValue { $0.injections }
    }

    /// Clear the list of recorded context injections.
    ///
    /// Clears the list of calls to `Instrument/inject(_:into:using:)`.
    public func clearPerformedContextInjections() {
        _state.withValue { $0.injections = [] }
    }

    /// A type that represents a recorded call to the In-memory tracer's inject method.
    public struct Injection: Sendable {
        /// The context from which values were being injected.
        public let context: ServiceContext
        /// The injected values;  the trace and span identifiers of the propagated span.
        public let values: [String: String]
    }
}

extension InMemoryTracer {

    /// Retrieves and returns the service context from the tracing carrier.
    /// - Parameters:
    ///   - carrier: The service implementation from which to extract the service context.
    ///   - context:The service context to update.
    ///   - extractor: The type that transfers service context from a carrier.
    public func extract<Carrier, Extract: Extractor>(
        _ carrier: Carrier,
        into context: inout ServiceContext,
        using extractor: Extract
    ) where Carrier == Extract.Carrier {
        defer {
            if self.recordExtractions {
                let extraction = Extraction(carrier: carrier, context: context)
                _state.withValue { $0.extractions.append(extraction) }
            }
        }

        guard let traceID = extractor.extract(key: Self.traceIDKey, from: carrier),
            let spanID = extractor.extract(key: Self.spanIDKey, from: carrier)
        else {
            return
        }

        context.inMemorySpanContext = InMemorySpanContext(traceID: traceID, spanID: spanID, parentSpanID: nil)
    }

    /// Lists all recorded calls to this tracer's extract method.
    ///
    /// Lists calls to `Instrument/extract(_:into:using:)`.
    /// This may be used to inspect the span identifiers extracted from an incoming carrier object into `ServiceContext`.
    public var performedContextExtractions: [Extraction] {
        _state.withValue { $0.extractions }
    }

    /// Represents a recorded call to the In-memory tracer's extract method.
    public struct Extraction: Sendable {
        /// The carrier object from which the context values were extracted from, such as  an HTTP request.
        public let carrier: any Sendable
        /// The constructed service context, containing the extracted in-memory span context.
        public let context: ServiceContext
    }
}

// MARK: - ID Generator

extension InMemoryTracer {

    /// A type that generates trace and span IDs for the in-memory tracer.
    /// You can customize how trace and span IDs are generated for the ``InMemoryTracer``.
    ///
    /// The defaul implementation, ``incrementing``, provides a simple sequential numeric scheme,
    /// for example `span-1`, `span-2`, `trace-1`, `trace-2`, and so on.
    public struct IDGenerator: Sendable {
        /// A closure that creates a trace ID.
        public let nextTraceID: @Sendable () -> String
        /// A closure that creates a span ID.
        public let nextSpanID: @Sendable () -> String

        /// Creates a new instance of an ID generator using the closures you provide.
        /// - Parameters:
        ///   - nextTraceID: The closure to create the next trace ID.
        ///   - nextSpanID: The closure to create the next span ID.
        public init(
            nextTraceID: @Sendable @escaping () -> String,
            nextSpanID: @Sendable @escaping () -> String
        ) {
            self.nextTraceID = nextTraceID
            self.nextSpanID = nextSpanID
        }

        /// An ID generator that provides incrementing IDs using a simple sequential numeric scheme.
        public static var incrementing: IDGenerator {
            let traceID = LockedValueBox<Int>(0)
            let spanID = LockedValueBox<Int>(0)

            return IDGenerator(
                nextTraceID: {
                    let value = traceID.withValue {
                        $0 += 1
                        return $0
                    }
                    return "trace-\(value)"
                },
                nextSpanID: {
                    let value = spanID.withValue {
                        $0 += 1
                        return $0
                    }
                    return "span-\(value)"
                }
            )
        }
    }
}
