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

public struct TestTracer: Tracer {
    public let idGenerator: IDGenerator

    public init(idGenerator: IDGenerator = .incrementing) {
        self.idGenerator = idGenerator
    }

    // MARK: - Tracer

    public func startSpan<Instant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> TestSpan where Instant: TracerInstant {
        let parentContext = context()
        let spanContext: TestSpanContext

        if let parentSpanContext = parentContext.testSpanContext {
            // child span
            spanContext = TestSpanContext(
                traceID: parentSpanContext.traceID,
                spanID: idGenerator.nextSpanID(),
                parentSpanID: parentSpanContext.spanID
            )
        } else {
            // root span
            spanContext = TestSpanContext(
                traceID: idGenerator.nextTraceID(),
                spanID: idGenerator.nextSpanID(),
                parentSpanID: nil
            )
        }

        var context = parentContext
        context.testSpanContext = spanContext

        let span = TestSpan(
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

    public func activeSpan(identifiedBy context: ServiceContext) -> TestSpan? {
        guard let spanContext = context.testSpanContext else { return nil }
        return _activeSpans.withValue { $0[spanContext] }
    }

    public func forceFlush() {
        _numberOfForceFlushes.withValue { $0 += 1 }
    }

    public var numberOfForceFlushes: Int {
        _numberOfForceFlushes.withValue { $0 }
    }

    public var finishedSpans: [FinishedTestSpan] {
        _finishedSpans.withValue { $0 }
    }

    private let _activeSpans = LockedValueBox<[TestSpanContext: TestSpan]>([:])
    private let _finishedSpans = LockedValueBox<[FinishedTestSpan]>([])
    private let _numberOfForceFlushes = LockedValueBox<Int>(0)

    // MARK: - Instrument

    public static let traceIDKey = "test-trace-id"
    public static let spanIDKey = "test-span-id"

    public func inject<Carrier, Inject: Injector>(
        _ context: ServiceContext,
        into carrier: inout Carrier,
        using injector: Inject
    ) where Carrier == Inject.Carrier {
        var values = [String: String]()

        if let spanContext = context.testSpanContext {
            injector.inject(spanContext.traceID, forKey: Self.traceIDKey, into: &carrier)
            values[Self.traceIDKey] = spanContext.traceID
            injector.inject(spanContext.spanID, forKey: Self.spanIDKey, into: &carrier)
            values[Self.spanIDKey] = spanContext.spanID
        }

        let injection = Injection(context: context, values: values)
        _injections.withValue { $0.append(injection) }
    }

    public var injections: [Injection] {
        _injections.withValue { $0 }
    }

    public func extract<Carrier, Extract: Extractor>(
        _ carrier: Carrier,
        into context: inout ServiceContext,
        using extractor: Extract
    ) where Carrier == Extract.Carrier {
        defer {
            let extraction = Extraction(carrier: carrier, context: context)
            _extractions.withValue { $0.append(extraction) }
        }

        guard let traceID = extractor.extract(key: Self.traceIDKey, from: carrier),
            let spanID = extractor.extract(key: Self.spanIDKey, from: carrier)
        else {
            return
        }

        context.testSpanContext = TestSpanContext(traceID: traceID, spanID: spanID, parentSpanID: nil)
    }

    public var extractions: [Extraction] {
        _extractions.withValue { $0 }
    }

    public struct Injection: Sendable {
        public let context: ServiceContext
        public let values: [String: String]
    }

    public struct Extraction: Sendable {
        public let carrier: any Sendable
        public let context: ServiceContext
    }

    private let _injections = LockedValueBox<[Injection]>([])
    private let _extractions = LockedValueBox<[Extraction]>([])
}

// MARK: - ID Generator

extension TestTracer {
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
