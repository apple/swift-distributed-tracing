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
        InstrumentationSystem.bootstrap(tracer)

        let httpServer = FakeHTTPServer { context, _, client -> FakeHTTPResponse in
            client.performRequest(context, request: FakeHTTPRequest(path: "/test", headers: []))
            return FakeHTTPResponse(status: 418)
        }

        httpServer.receive(FakeHTTPRequest(path: "/", headers: [("trace-id", "test")]))

        XCTAssertEqual(tracer.spans.count, 2)
        for span in tracer.spans {
            XCTAssertEqual(span.context.traceID, "test")
        }
    }

    func testContextPropagationWithNoOpSpan() {
        let httpServer = FakeHTTPServer { context, _, client -> FakeHTTPResponse in
            var context = BaggageContext()
            context.traceID = "test"
            client.performRequest(context, request: FakeHTTPRequest(path: "/test", headers: []))
            return FakeHTTPResponse(status: 418)
        }

        httpServer.receive(FakeHTTPRequest(path: "/", headers: [("trace-id", "test")]))

        XCTAssertEqual(httpServer.client.contexts.count, 1)
        XCTAssertEqual(httpServer.client.contexts.first?.traceID, "test")
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

    private let catchAllHandler: Handler
    let client: FakeHTTPClient

    init(catchAllHandler: @escaping Handler) {
        self.catchAllHandler = catchAllHandler
        self.client = FakeHTTPClient()
    }

    func receive(_ request: FakeHTTPRequest) {
        let tracer = InstrumentationSystem.tracer

        var context = BaggageContext()
        InstrumentationSystem.instrument.extract(request.headers, into: &context, using: HTTPHeadersExtractor())

        let span = tracer.startSpan(named: "GET \(request.path)", context: context)

        let response = self.catchAllHandler(span.context, request, self.client)
        span.attributes["http.status"] = .int(response.status)

        span.end()
    }
}

// MARK: - Fake HTTP Client

final class FakeHTTPClient {
    private(set) var contexts = [BaggageContext]()

    func performRequest(_ context: BaggageContext, request: FakeHTTPRequest) {
        var request = request
        let span = InstrumentationSystem.tracer
            .startSpan(named: "GET \(request.path)", context: context, ofKind: .client)
        self.contexts.append(span.context)
        InstrumentationSystem.instrument.inject(context, into: &request.headers, using: HTTPHeadersInjector())
        span.end()
    }
}
