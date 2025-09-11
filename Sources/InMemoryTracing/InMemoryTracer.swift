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

/// An in-memory implementation of the ``Tracer`` protocol which can be used either in testing,
/// or in manual collecting and interrogating traces within a process, and acting on them programatically.
///
/// ### Span lifecycle
/// This tracer does _not_ automatically remove spans once they end.
/// Finished spans are retained and available for inspection using the `finishedSpans` property.
/// Spans which have been started but have not yet been called `Span/end()` on are also available
/// for inspection using the ``activeSpans`` property.
///
/// Spans are retained by the `InMemoryTracer` until they are explicitly removed, e.g. by using
/// ``popFinishedSpans()`` or any of the `clear...` methods (e.g. ``clearFinishedSpans()``)
public struct InMemoryTracer: Tracer {

    public let idGenerator: IDGenerator

    public let recordInjections: Bool
    public let recordExtractions: Bool

    private let _activeSpans = LockedValueBox<[InMemorySpanContext: InMemorySpan]>([:])
    private let _finishedSpans = LockedValueBox<[FinishedInMemorySpan]>([])
    private let _numberOfForceFlushes = LockedValueBox<Int>(0)

    private let _injections = LockedValueBox<[Injection]>([])
    private let _extractions = LockedValueBox<[Extraction]>([])

    /// Create a new ``InMemoryTracer``.
    ///
    /// - Parameters:
    ///   - Parameter idGenerator: strategy for generating trace and span identifiers
    ///   - Parameter idGenerator: strategy for generating trace and span identifiers
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
            _activeSpans.withValue { $0[spanContext] = nil }
            _finishedSpans.withValue { $0.append(finishedSpan) }
        }
        _activeSpans.withValue { $0[spanContext] = span }
        return span
    }

    public func forceFlush() {
        _numberOfForceFlushes.withValue { $0 += 1 }
    }
}

// MARK: - InMemoryTracer querying

extension InMemoryTracer {

    /// Array of active spans, i.e. spans which have been started but have not yet finished (by calling `Span/end()`).
    public var activeSpans: [InMemorySpan] {
        _activeSpans.withValue { active in Array(active.values) }
    }

    /// Retrives a specific _active_ span, identified by the specific span, trace, and parent ID's
    /// stored in the `inMemorySpanContext`
    public func activeSpan(identifiedBy context: ServiceContext) -> InMemorySpan? {
        guard let spanContext = context.inMemorySpanContext else { return nil }
        return _activeSpans.withValue { $0[spanContext] }
    }

    /// Count of the number of times ``Tracer/forceFlush()`` was called on this tracer.
    public var numberOfForceFlushes: Int {
        _numberOfForceFlushes.withValue { $0 }
    }

    /// Gets, without removing, all the finished spans recorded by this tracer.
    ///
    /// - SeeAlso: `popFinishedSpans()`
    public var finishedSpans: [FinishedInMemorySpan] {
        _finishedSpans.withValue { $0 }
    }

    /// Returns, and removes, all finished spans recorded by this tracer.
    public func popFinishedSpans() -> [FinishedInMemorySpan] {
        _finishedSpans.withValue { spans in
            defer { spans = [] }
            return spans
        }
    }

    /// Atomically clears any stored finished spans in this tracer.
    public func clearFinishedSpans() {
        _finishedSpans.withValue { $0 = [] }
    }

    /// Clears all registered finished spans, as well as injections/extractions performed by this tracer.
    public func clearAll(includingActive: Bool = false) {
        _finishedSpans.withValue { $0 = [] }
        _injections.withValue { $0 = [] }
        _extractions.withValue { $0 = [] }
        if includingActive { 
            _activeSpans.withValue { $0 = [:] }
        }
    }
}

// MARK: - Instrument

extension InMemoryTracer {

    public static let traceIDKey = "in-memory-trace-id"
    public static let spanIDKey = "in-memory-span-id"

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
            _injections.withValue { $0.append(injection) }
        }
    }

    /// Lists all recorded calls to this tracer's ``Instrument/inject(_:into:using:)`` method.
    /// This may be used to inspect what span identifiers are being propagated by this tracer.
    public var performedContextInjections: [Injection] {
        _injections.withValue { $0 }
    }

    /// Clear the list of recorded context injections (calls to ``Instrument/inject(_:into:using:)``).
    public func clearPerformedContextInjections() {
        _injections.withValue { $0 = [] }
    }

    /// Represents a recorded call to the InMemoryTracer's ``Instrument/inject(_:into:using:)`` method.
    public struct Injection: Sendable {
        /// The context from which values were being injected.
        public let context: ServiceContext
        /// The injected values, these will be specifically the trace and span identifiers of the propagated span.
        public let values: [String: String]
    }
}

extension InMemoryTracer {

    public func extract<Carrier, Extract: Extractor>(
        _ carrier: Carrier,
        into context: inout ServiceContext,
        using extractor: Extract
    ) where Carrier == Extract.Carrier {
        defer {
            if self.recordExtractions {
                let extraction = Extraction(carrier: carrier, context: context)
                _extractions.withValue { $0.append(extraction) }
            }
        }

        guard let traceID = extractor.extract(key: Self.traceIDKey, from: carrier),
            let spanID = extractor.extract(key: Self.spanIDKey, from: carrier)
        else {
            return
        }

        context.inMemorySpanContext = InMemorySpanContext(traceID: traceID, spanID: spanID, parentSpanID: nil)
    }

    /// Lists all recorded calls to this tracer's ``Instrument/extract(_:into:using:)`` method.
    /// This may be used to inspect what span identifiers were extracted from an incoming carrier object into ``ServiceContext``.
    public var performedContextExtractions: [Extraction] {
        _extractions.withValue { $0 }
    }

    /// Represents a recorded call to the InMemoryTracer's ``Instrument/extract(_:into:using:)`` method.
    public struct Extraction: Sendable {
        /// The carrier object from which the context values were extracted from,
        /// e.g. this frequently is an HTTP request or similar.
        public let carrier: any Sendable
        /// The constructed service context, containing the extracted ``ServiceContext/inMemorySpanContext``.
        public let context: ServiceContext
    }
}

// MARK: - ID Generator

extension InMemoryTracer {

    /// Can be used to customize how trace and span IDs are generated by the ``InMemoryTracer``.
    ///
    /// Defaults to a simple sequential numeric scheme (`span-1`, `span-2`, `trace-1`, `trace-2` etc).
    public struct IDGenerator: Sendable {
        public let nextTraceID: @Sendable () -> String
        public let nextSpanID: @Sendable () -> String

        public init(
            nextTraceID: @Sendable @escaping () -> String,
            nextSpanID: @Sendable @escaping () -> String
        ) {
            self.nextTraceID = nextTraceID
            self.nextSpanID = nextSpanID
        }

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
