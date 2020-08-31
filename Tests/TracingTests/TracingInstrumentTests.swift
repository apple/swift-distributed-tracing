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
import BaggageLogging
@testable import Instrumentation
import Tracing
import XCTest

final class TracingInstrumentTests: XCTestCase {
    func testPlayground() {
        let httpServer = FakeHTTPServer(instrument: TestTracer()) { context, _, client -> FakeHTTPResponse in
            client.performRequest(context, request: FakeHTTPRequest(path: "/test", headers: []))
            return FakeHTTPResponse(status: 418)
        }

        httpServer.receive(FakeHTTPRequest(path: "/", headers: []))
    }

    func testItProvidesAccessToATracingInstrument() {
        let tracer = TestTracer()

        XCTAssertNil(InstrumentationSystem.tracingInstrument(of: TestTracer.self))

        InstrumentationSystem.bootstrapInternal(tracer)
        XCTAssertFalse(InstrumentationSystem.instrument is MultiplexInstrument)
        XCTAssert(InstrumentationSystem.instrument(of: TestTracer.self) === tracer)
        XCTAssertNil(InstrumentationSystem.instrument(of: NoOpInstrument.self))

        XCTAssert(InstrumentationSystem.tracingInstrument(of: TestTracer.self) === tracer)
        XCTAssert(InstrumentationSystem.tracingInstrument is TestTracer)

        let multiplexInstrument = MultiplexInstrument([tracer])
        InstrumentationSystem.bootstrapInternal(multiplexInstrument)
        XCTAssert(InstrumentationSystem.instrument is MultiplexInstrument)
        XCTAssert(InstrumentationSystem.instrument(of: TestTracer.self) === tracer)

        XCTAssert(InstrumentationSystem.tracingInstrument(of: TestTracer.self) === tracer)
        XCTAssert(InstrumentationSystem.tracingInstrument is TestTracer)
    }
}

// MARK: - TestTracer

final class TestTracer: TracingInstrument {
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
        return span
    }

    public func forceFlush() {}

    func extract<Carrier, Extractor>(_ carrier: Carrier, into context: inout BaggageContext, using extractor: Extractor)
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier {
        let traceParent = extractor.extract(key: "traceparent", from: carrier)
            ?? "00-0af7651916cd43dd8448eb211c80319c-b9c7c989f97918e1-01"

        let traceParentComponents = traceParent.split(separator: "-")
        precondition(traceParentComponents.count == 4, "Invalid traceparent format")
        let traceID = String(traceParentComponents[1])
        let parentID = String(traceParentComponents[2])
        context[TraceParentKey.self] = TraceParent(traceID: traceID, parentID: parentID)
    }

    func inject<Carrier, Injector>(_ context: BaggageContext, into carrier: inout Carrier, using injector: Injector)
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier {
        guard let traceParent = context[TraceParentKey.self] else { return }
        let traceParentHeader = "00-\(traceParent.traceID)-\(traceParent.parentID)-00"
        injector.inject(traceParentHeader, forKey: "traceparent", into: &carrier)
    }
}

extension TestTracer {
    struct TraceParent {
        let traceID: String
        let parentID: String
    }

    enum TraceParentKey: BaggageContextKey {
        typealias Value = TraceParent
    }
}

// MARK: - TestSpan

struct TestSpan: Span {
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

    mutating func setStatus(_ status: SpanStatus) {
        self.status = status
        self.isRecording = true
    }

    mutating func addLink(_ link: SpanLink) {
        self.links.append(link)
    }

    mutating func addEvent(_ event: SpanEvent) {
        self.events.append(event)
    }

    func recordError(_ error: Error) {}

    mutating func end(at timestamp: Timestamp) {
        self.endTimestamp = timestamp
        self.onEnd(self)
    }
}

// MARK: - Fake HTTP Server

typealias HTTPHeaders = [(String, String)]

struct HTTPHeadersExtractor: ExtractorProtocol {
    func extract(key: String, from headers: HTTPHeaders) -> String? {
        return headers.first(where: { $0.0 == key })?.1
    }
}

struct HTTPHeadersInjector: InjectorProtocol {
    func inject(_ value: String, forKey key: String, into headers: inout HTTPHeaders) {
        headers.append((key, value))
    }
}

struct FakeHTTPRequest {
    let path: String
    var headers: HTTPHeaders
}

struct FakeHTTPResponse {
    let status: Int
}

struct FakeHTTPServer {
    typealias Handler = (BaggageContext, FakeHTTPRequest, FakeHTTPClient) -> FakeHTTPResponse

    private let instrument: Instrument
    private let catchAllHandler: Handler
    private let client: FakeHTTPClient

    init(instrument: Instrument, catchAllHandler: @escaping Handler) {
        self.instrument = instrument
        self.catchAllHandler = catchAllHandler
        self.client = FakeHTTPClient(instrument: instrument)
    }

    func receive(_ request: FakeHTTPRequest) {
        // TODO: - Consider a nicer way to access a certain instrument
        let tracer = self.instrument as! TracingInstrument

        var context = BaggageContext()
        self.instrument.extract(request.headers, into: &context, using: HTTPHeadersExtractor())

        var span = tracer.startSpan(named: "GET \(request.path)", context: context)

        let response = self.catchAllHandler(span.context, request, self.client)
        span.attributes["http.status"] = .int(response.status)

        span.end()
    }
}

// MARK: - Fake HTTP Client

struct FakeHTTPClient {
    private let instrument: Instrument

    init(instrument: Instrument) {
        self.instrument = instrument
    }

    func performRequest(_ context: BaggageContext, request: FakeHTTPRequest) {
        var request = request
        self.instrument.inject(context, into: &request.headers, using: HTTPHeadersInjector())
    }
}
