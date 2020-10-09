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
import Instrumentation
import Logging
import NIO
import NIOHTTP1
import NIOInstrumentation

struct InstrumentedHTTPClient {
    private let client: HTTPClient
    private let instrument: Instrument
    private let logger = Logger(label: "InstrumentedHTTPClient")

    init(instrument: Instrument, eventLoopGroupProvider: HTTPClient.EventLoopGroupProvider) {
        self.client = HTTPClient(eventLoopGroupProvider: eventLoopGroupProvider)
        self.instrument = instrument
    }

    // TODO: deadline: NIODeadline? would move into baggage?
    public func get(url: String, context: BaggageContext) -> EventLoopFuture<HTTPClient.Response> {
        do {
            let request = try HTTPClient.Request(url: url, method: .GET)
            return self.execute(request: request, context: context)
        } catch {
            return self.client.eventLoopGroup.next().makeFailedFuture(error)
        }
    }

    func execute(request: HTTPClient.Request, context: BaggageContext) -> EventLoopFuture<HTTPClient.Response> {
        var request = request
        self.instrument.inject(context.baggage, into: &request.headers, using: HTTPHeadersInjector())
        context.logger.info("🌎 InstrumentedHTTPClient: Execute request")
        return self.client.execute(request: request)
    }

    func syncShutdown() throws {
        try self.client.syncShutdown()
    }
}
