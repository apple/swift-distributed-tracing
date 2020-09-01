//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020 Moritz Lang and the Swift Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Baggage
import Foundation
import Instrumentation
import Tracing

final class TestTracer: Tracer {
    private(set) var spans = [TestSpan]()

    func startSpan(
        named operationName: String,
        context: BaggageContextCarrier,
        ofKind kind: SpanKind,
        at timestamp: Timestamp
    ) -> Span {
        let span = TestSpan(
            operationName: operationName,
            startTimestamp: timestamp,
            context: context.baggage,
            kind: kind
        ) { _ in }
        self.spans.append(span)
        return span
    }

    public func forceFlush() {}

    func extract<Carrier, Extractor>(_ carrier: Carrier, into context: inout BaggageContext, using extractor: Extractor)
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier
    {
        let traceID = extractor.extract(key: "trace-id", from: carrier) ?? UUID().uuidString
        context.traceID = traceID
    }

    func inject<Carrier, Injector>(_ context: BaggageContext, into carrier: inout Carrier, using injector: Injector)
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier
    {
        guard let traceID = context.traceID else { return }
        injector.inject(traceID, forKey: "trace-id", into: &carrier)
    }
}

extension TestTracer {
    enum TraceIDKey: BaggageContextKey {
        typealias Value = String
    }
}

extension BaggageContext {
    var traceID: String? {
        get {
            return self[TestTracer.TraceIDKey.self]
        }
        set {
            self[TestTracer.TraceIDKey.self] = newValue
        }
    }
}

final class TestSpan: Span {
    private let operationName: String
    private let kind: SpanKind

    private var status: SpanStatus?

    private let startTimestamp: Timestamp
    private(set) var endTimestamp: Timestamp?

    let context: BaggageContext

    private(set) var events = [SpanEvent]() {
        didSet {
            self.isRecording = !self.events.isEmpty
        }
    }

    private(set) var links = [SpanLink]()

    var attributes: SpanAttributes = [:] {
        didSet {
            self.isRecording = !self.attributes.isEmpty
        }
    }

    private(set) var isRecording = false

    let onEnd: (Span) -> Void

    init(
        operationName: String,
        startTimestamp: Timestamp,
        context: BaggageContext,
        kind: SpanKind,
        onEnd: @escaping (Span) -> Void
    ) {
        self.operationName = operationName
        self.startTimestamp = startTimestamp
        self.context = context
        self.onEnd = onEnd
        self.kind = kind
    }

    func setStatus(_ status: SpanStatus) {
        self.status = status
        self.isRecording = true
    }

    func addLink(_ link: SpanLink) {
        self.links.append(link)
    }

    func addEvent(_ event: SpanEvent) {
        self.events.append(event)
    }

    func recordError(_ error: Error) {}

    func end(at timestamp: Timestamp) {
        self.endTimestamp = timestamp
        self.onEnd(self)
    }
}
