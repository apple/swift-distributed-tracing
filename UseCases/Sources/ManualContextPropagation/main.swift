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
import Foundation
import Instrumentation

// MARK: - Fake HTTP Server

typealias HTTPHeaders = [(String, String)]

struct HTTPHeadersExtractor: Extractor {
    func extract(key: String, from headers: HTTPHeaders) -> String? {
        return headers.first(where: { $0.0 == key })?.1
    }
}

struct HTTPHeadersInject: Injector {
    func inject(_ value: String, forKey key: String, into headers: inout HTTPHeaders) {
        headers.append((key, value))
    }
}

struct FakeHTTPRequest {
    let path: String
    var headers: HTTPHeaders
}

struct FakeHTTPResponse {}

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
        var context = DefaultContext(baggage: .topLevel, logger: .init(label: "test"))
        context.logger.info("\(String(describing: FakeHTTPRequest.self)): Extracting context values from request headers into context")
        self.instrument.extract(request.headers, into: &context.baggage, using: HTTPHeadersExtractor())
        _ = self.catchAllHandler(context, request, self.client)
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
        context.logger.info("\(String(describing: FakeHTTPClient.self)): Injecting context values into request headers")
        self.instrument.inject(context.baggage, into: &request.headers, using: HTTPHeadersInjector())
        print(request)
    }
}

// MARK: - Fake Tracer

private final class FakeTracer: Instrument {
    enum TraceIDKey: Baggage.Key {
        typealias Value = String
    }

    static let headerName = "fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    func inject<Carrier, Inject>(_ baggage: Baggage, into carrier: inout Carrier, using injector: Inject)
        where
        Inject: Injector,
        Carrier == Inject.Carrier {
        guard let traceID = baggage[TraceIDKey.self] else { return }
        injector.inject(traceID, forKey: FakeTracer.headerName, into: &carrier)
    }

    func extract<Carrier, Extract>(_ carrier: Carrier, into baggage: inout Baggage, using extractor: Extract)
        where
        Extract: Extractor,
        Carrier == Extract.Carrier {
        let traceID = extractor.extract(key: FakeTracer.headerName, from: carrier) ?? FakeTracer.defaultTraceID
        baggage[TraceIDKey.self] = traceID
    }
}

// MARK: - Demo

let server = FakeHTTPServer(instrument: FakeTracer()) { context, _, client in
    context.logger.info("Perform subsequent request")
    let outgoingRequest = FakeHTTPRequest(path: "/other-service", headers: [("Content-Type", "application/json")])
    client.performRequest(context, request: outgoingRequest)
    return FakeHTTPResponse()
}

print("=== Receive HTTP request on server ===")
server.receive(FakeHTTPRequest(path: "/", headers: []))
