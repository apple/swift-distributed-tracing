//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Baggage
@testable import Instrumentation
import Tracing
import XCTest

final class TracerTests: XCTestCase {
    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }

    func testContextPropagation() {
        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(NoOpTracer())
        }

        let httpServer = FakeHTTPServer { context, _, client -> FakeHTTPResponse in
            client.performRequest(context, request: FakeHTTPRequest(path: "/test", headers: []))
            return FakeHTTPResponse(status: 418)
        }

        httpServer.receive(FakeHTTPRequest(path: "/", headers: [("trace-id", "test")]))

        XCTAssertEqual(tracer.spans.count, 2)
        for span in tracer.spans {
            XCTAssertEqual(span.baggage.traceID, "test")
        }
    }

    func testContextPropagationWithNoOpSpan() {
        let httpServer = FakeHTTPServer { _, _, client -> FakeHTTPResponse in
            var baggage = Baggage.topLevel
            baggage.traceID = "test"
            client.performRequest(baggage, request: FakeHTTPRequest(path: "/test", headers: []))
            return FakeHTTPResponse(status: 418)
        }

        httpServer.receive(FakeHTTPRequest(path: "/", headers: [("trace-id", "test")]))

        XCTAssertEqual(httpServer.client.baggages.count, 1)
        XCTAssertEqual(httpServer.client.baggages.first?.traceID, "test")
    }

    func testWithSpan_success() {
        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(NoOpTracer())
        }

        var spanEnded = false
        tracer.onEndSpan = { _ in spanEnded = true }

        let value = tracer.withSpan("hello", baggage: .topLevel) { _ in
            "yes"
        }

        XCTAssertEqual(value, "yes")
        // XCTAssertEqual(spanEnded, true)
    }

    func testWithSpan_throws() {
        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(NoOpTracer())
        }

        var spanEnded = false
        tracer.onEndSpan = { _ in spanEnded = true }

        do {
            _ = try tracer.withSpan("hello", baggage: .topLevel) { _ in
                throw ExampleSpanError()
            }
        } catch {
            XCTAssertEqual(spanEnded, true)
            XCTAssertEqual(error as? ExampleSpanError, ExampleSpanError())
            return
        }
        XCTFail("Should have throw")
    }
}

struct ExampleSpanError: Error, Equatable {}

// MARK: - Fake HTTP Server

typealias HTTPHeaders = [(String, String)]

struct HTTPHeadersExtractor: Extractor {
    func extract(key: String, from headers: HTTPHeaders) -> String? {
        return headers.first(where: { $0.0 == key })?.1
    }
}

struct HTTPHeadersInjector: Injector {
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
    typealias Handler = (Baggage, FakeHTTPRequest, FakeHTTPClient) -> FakeHTTPResponse

    private let catchAllHandler: Handler
    let client: FakeHTTPClient

    init(catchAllHandler: @escaping Handler) {
        self.catchAllHandler = catchAllHandler
        self.client = FakeHTTPClient()
    }

    func receive(_ request: FakeHTTPRequest) {
        let tracer = InstrumentationSystem.tracer

        var baggage = Baggage.topLevel
        InstrumentationSystem.instrument.extract(request.headers, into: &baggage, using: HTTPHeadersExtractor())

        let span = tracer.startSpan("GET \(request.path)", baggage: baggage)

        let response = self.catchAllHandler(span.baggage, request, self.client)
        span.attributes["http.status"] = response.status

        span.end()
    }
}

// MARK: - Fake HTTP Client

final class FakeHTTPClient {
    private(set) var baggages = [Baggage]()

    func performRequest(_ baggage: Baggage, request: FakeHTTPRequest) {
        var request = request
        let span = InstrumentationSystem.tracer.startSpan("GET \(request.path)", baggage: baggage)
        self.baggages.append(span.baggage)
        InstrumentationSystem.instrument.inject(baggage, into: &request.headers, using: HTTPHeadersInjector())
        span.end()
    }
}
