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
import TracingInstrumentation
import XCTest

final class TracingInstrumentTests: XCTestCase {
    func testPlayground() {
        let httpServer = FakeHTTPServer(instrument: JaegerTracer()) { baggage, _, client -> FakeHTTPResponse in
            baggage.logger.info("Make subsequent HTTP request")
            client.performRequest(baggage, request: FakeHTTPRequest(path: "/test", headers: []))
            return FakeHTTPResponse(status: 418)
        }

        httpServer.receive(FakeHTTPRequest(path: "/", headers: []))
    }

    func testItProvidesAccessToATracingInstrument() {
        let tracer = JaegerTracer()

        XCTAssertNil(InstrumentationSystem.tracingInstrument(of: JaegerTracer.self))

        InstrumentationSystem.bootstrapInternal(tracer)
        XCTAssertFalse(InstrumentationSystem.instrument is MultiplexInstrument)
        XCTAssert(InstrumentationSystem.instrument(of: JaegerTracer.self) === tracer)
        XCTAssertNil(InstrumentationSystem.instrument(of: NoOpInstrument.self))

        XCTAssert(InstrumentationSystem.tracingInstrument(of: JaegerTracer.self) === tracer)
        XCTAssert(InstrumentationSystem.tracingInstrument is JaegerTracer)

        let multiplexInstrument = MultiplexInstrument([tracer])
        InstrumentationSystem.bootstrapInternal(multiplexInstrument)
        XCTAssert(InstrumentationSystem.instrument is MultiplexInstrument)
        XCTAssert(InstrumentationSystem.instrument(of: JaegerTracer.self) === tracer)

        XCTAssert(InstrumentationSystem.tracingInstrument(of: JaegerTracer.self) === tracer)
        XCTAssert(InstrumentationSystem.tracingInstrument is JaegerTracer)


    }
}

// MARK: - JaegerTracer

final class JaegerTracer: TracingInstrument {
    func startSpan(
        named operationName: String,
        context: BaggageContext,
        ofKind kind: SpanKind,
        at timestamp: Timestamp?
    ) -> Span {
        let span = OTSpan(
            operationName: operationName,
            startTimestamp: timestamp ?? .now(),
            context: context,
            kind: kind
        ) { span in
            span.baggage.logger.info(#"Emitting span "\#(span.operationName)" to backend"#)
            span.baggage.logger.info("\(span.attributes)")
        }
        return span
    }

    func extract<Carrier, Extractor>(
        _ carrier: Carrier, into baggage: inout BaggageContext, using extractor: Extractor
    )
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier {
        let traceParent = extractor.extract(key: "traceparent", from: carrier)
            ?? "00-0af7651916cd43dd8448eb211c80319c-b9c7c989f97918e1-01"

        let traceParentComponents = traceParent.split(separator: "-")
        precondition(traceParentComponents.count == 4, "Invalid traceparent format")
        let traceID = String(traceParentComponents[1])
        let parentID = String(traceParentComponents[2])
        baggage[TraceParentKey.self] = TraceParent(traceID: traceID, parentID: parentID)
    }

    func inject<Carrier, Injector>(
        _ baggage: BaggageContext, into carrier: inout Carrier, using injector: Injector
    )
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier {
        guard let traceParent = baggage[TraceParentKey.self] else { return }
        let traceParentHeader = "00-\(traceParent.traceID)-\(traceParent.parentID)-00"
        injector.inject(traceParentHeader, forKey: "traceparent", into: &carrier)
    }
}

extension JaegerTracer {
    struct TraceParent {
        let traceID: String
        let parentID: String
    }

    enum TraceParentKey: BaggageContextKey {
        typealias Value = TraceParent
    }
}

// MARK: - OTSpan

struct OTSpan: Span {
    let operationName: String
    let kind: SpanKind

    var status: SpanStatus? {
        didSet {
            self.isRecording = self.status != nil
        }
    }

    let startTimestamp: Timestamp
    private(set) var endTimestamp: Timestamp?

    let baggage: BaggageContext

    private(set) var events = [SpanEvent]() {
        didSet {
            self.isRecording = !self.events.isEmpty
        }
    }

    private var links = [SpanLink]()

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
        context baggage: BaggageContext,
        kind: SpanKind,
        onEnd: @escaping (Span) -> Void
    ) {
        self.operationName = operationName
        self.startTimestamp = startTimestamp
        self.baggage = baggage
        self.onEnd = onEnd
        self.kind = kind
    }

    mutating func addLink(_ link: SpanLink) {
        self.links.append(link)
    }

    mutating func addEvent(_ event: SpanEvent) {
        self.events.append(event)
    }

    mutating func end(at timestamp: Timestamp) {
        self.endTimestamp = timestamp
        self.onEnd(self)
    }
}

// MARK: - Fake HTTP Server

typealias HTTPHeaders = [(String, String)]

struct HTTPHeadersExtractor: ExtractorProtocol {
    func extract(key: String, from headers: HTTPHeaders) -> String? {
        headers.first(where: { $0.0 == key })?.1
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

        let response = self.catchAllHandler(span.baggage, request, self.client)
        span.baggage.logger.info("Handled HTTP request with status: \(response.status)")
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

    func performRequest(_ baggage: BaggageContext, request: FakeHTTPRequest) {
        var request = request
        self.instrument.inject(baggage, into: &request.headers, using: HTTPHeadersInjector())
        baggage.logger.info("Performing outgoing HTTP request")
    }
}
