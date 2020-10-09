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
        baggage: Baggage,
        ofKind kind: SpanKind,
        at timestamp: Timestamp
    ) -> Span {
        let span = TestSpan(
            operationName: operationName,
            startTimestamp: timestamp,
            baggage: baggage,
            kind: kind
        ) { _ in }
        self.spans.append(span)
        return span
    }

    public func forceFlush() {}

    func extract<Carrier, Extractor>(_ carrier: Carrier, into baggage: inout Baggage, using extractor: Extractor)
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier
    {
        let traceID = extractor.extract(key: "trace-id", from: carrier) ?? UUID().uuidString
        baggage.traceID = traceID
    }

    func inject<Carrier, Injector>(_ baggage: Baggage, into carrier: inout Carrier, using injector: Injector)
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier
    {
        guard let traceID = baggage.traceID else { return }
        injector.inject(traceID, forKey: "trace-id", into: &carrier)
    }
}

extension TestTracer {
    enum TraceIDKey: Baggage.Key {
        typealias Value = String
    }
}

extension Baggage {
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

    let baggage: Baggage

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
        baggage: Baggage,
        kind: SpanKind,
        onEnd: @escaping (Span) -> Void
    ) {
        self.operationName = operationName
        self.startTimestamp = startTimestamp
        self.baggage = baggage
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
