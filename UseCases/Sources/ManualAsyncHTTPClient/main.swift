//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AsyncHTTPClient
import BaggageContext
import Foundation
import Instrumentation
import Logging
import NIOHTTP1
import NIOInstrumentation

let logger = Logger(label: "usecase")

// MARK: - InstrumentedHTTPClient

struct InstrumentedHTTPClient {
    private let client = HTTPClient(eventLoopGroupProvider: .createNew)
    private let instrument: Instrument

    init(instrument: Instrument) {
        self.instrument = instrument
    }

    func execute(request: HTTPClient.Request, context: BaggageContext) {
        var request = request
        self.instrument.inject(context.baggage, into: &request.headers, using: HTTPHeadersInjector())
        context.logger.info("Execute request using injected header values")
        print(request.headers)
    }
}

// MARK: - Fake HTTP Server

struct FakeHTTPResponse {}

struct FakeHTTPServer {
    typealias Handler = (BaggageContext, HTTPClient.Request, InstrumentedHTTPClient) -> FakeHTTPResponse

    private let instrument: Instrument
    private let catchAllHandler: Handler
    private let client: InstrumentedHTTPClient

    init(instrument: Instrument, catchAllHandler: @escaping Handler) {
        self.instrument = instrument
        self.catchAllHandler = catchAllHandler
        self.client = InstrumentedHTTPClient(instrument: instrument)
    }

    func receive(_ request: HTTPClient.Request) {
        var context = DefaultContext(baggage: .topLevel, logger: logger)
        context.logger.info("Extracting context values from request headers into context")
        self.instrument.extract(request.headers, into: &context.baggage, using: HTTPHeadersExtractor())
        _ = self.catchAllHandler(context, request, self.client)
    }
}

// MARK: - Fake Tracer

private final class FakeTracer: Instrument {
    enum TraceIDKey: Baggage.Key {
        typealias Value = String
    }

    static let headerName = "fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    func inject<Carrier, Injector>(_ baggage: Baggage, into carrier: inout Carrier, using injector: Injector)
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier
    {
        guard let traceID = baggage[TraceIDKey.self] else { return }
        injector.inject(traceID, forKey: FakeTracer.headerName, into: &carrier)
    }

    func extract<Carrier, Extractor>(_ carrier: Carrier, into baggage: inout Baggage, using extractor: Extractor)
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier
    {
        let traceID = extractor.extract(key: FakeTracer.headerName, from: carrier) ?? FakeTracer.defaultTraceID
        baggage[TraceIDKey.self] = traceID
    }
}

// MARK: - Demo

let server = FakeHTTPServer(
    instrument: FakeTracer()
) { context, _, client -> FakeHTTPResponse in
    context.logger.info("Perform subsequent request")
    let outgoingRequest = try! HTTPClient.Request(
        url: "https://swift.org",
        headers: ["Accept": "application/json"]
    )
    client.execute(request: outgoingRequest, context: context)
    return FakeHTTPResponse()
}

logger.info("Receive HTTP request on server")
server.receive(try! HTTPClient.Request(url: "https://swift.org"))
