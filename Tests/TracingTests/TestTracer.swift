//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2021 Apple Inc. and the Swift Distributed Tracing project
// authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Dispatch
import Foundation
import Instrumentation
import InstrumentationBaggage
import Tracing

/// Only intended to be used in single-threaded testing.
final class TestTracer: LegacyTracerProtocol {
    private(set) var spans = [TestSpan]()
    var onEndSpan: (TestSpan) -> Void = { _ in }

    func startAnySpan(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage,
        ofKind kind: SpanKind,
        at time: DispatchWallTime,
        function: String,
        file fileID: String,
        line: UInt
    ) -> any SpanProtocol {
        let span = TestSpan(
            operationName: operationName,
            startTime: time,
            baggage: baggage(),
            kind: kind,
            onEnd: onEndSpan
        )
        self.spans.append(span)
        return span
    }

    public func forceFlush() {}

    func extract<Carrier, Extract>(_ carrier: Carrier, into baggage: inout Baggage, using extractor: Extract)
        where
        Extract: Extractor,
        Carrier == Extract.Carrier
    {
        let traceID = extractor.extract(key: "trace-id", from: carrier) ?? UUID().uuidString
        baggage.traceID = traceID
    }

    func inject<Carrier, Inject>(_ baggage: Baggage, into carrier: inout Carrier, using injector: Inject)
        where
        Inject: Injector,
        Carrier == Inject.Carrier
    {
        guard let traceID = baggage.traceID else { return }
        injector.inject(traceID, forKey: "trace-id", into: &carrier)
    }
}

#if swift(>=5.7.0)
extension TestTracer: TracerProtocol {
    func startSpan(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage,
        ofKind kind: SpanKind,
        at time: DispatchWallTime,
        function: String,
        file fileID: String,
        line: UInt
    ) -> TestSpan {
        let span = TestSpan(
            operationName: operationName,
            startTime: time,
            baggage: baggage(),
            kind: kind,
            onEnd: onEndSpan
        )
        self.spans.append(span)
        return span
    }
}
#endif

extension TestTracer {
    enum TraceIDKey: BaggageKey {
        typealias Value = String
    }

    enum SpanIDKey: BaggageKey {
        typealias Value = String
    }
}

extension Baggage {
    var traceID: String? {
        get {
            self[TestTracer.TraceIDKey.self]
        }
        set {
            self[TestTracer.TraceIDKey.self] = newValue
        }
    }

    var spanID: String? {
        get {
            self[TestTracer.SpanIDKey.self]
        }
        set {
            self[TestTracer.SpanIDKey.self] = newValue
        }
    }
}

/// Only intended to be used in single-threaded testing.
final class TestSpan: SpanProtocol {
    private let kind: SpanKind

    private var status: SpanStatus?

    private let startTime: DispatchWallTime
    private(set) var endTime: DispatchWallTime?

    private(set) var recordedErrors: [(Error, SpanAttributes)] = []

    var operationName: String
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

    let onEnd: (TestSpan) -> Void

    init(
        operationName: String,
        startTime: DispatchWallTime,
        baggage: Baggage,
        kind: SpanKind,
        onEnd: @escaping (TestSpan) -> Void
    ) {
        self.operationName = operationName
        self.startTime = startTime
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

    func recordError(_ error: Error, attributes: SpanAttributes) {
        self.recordedErrors.append((error, attributes))
    }

    func end(at time: DispatchWallTime) {
        self.endTime = time
        self.onEnd(self)
    }
}

#if compiler(>=5.6.0)
extension TestTracer: @unchecked Sendable {} // only intended for single threaded testing
extension TestSpan: @unchecked Sendable {} // only intended for single threaded testing
#endif
