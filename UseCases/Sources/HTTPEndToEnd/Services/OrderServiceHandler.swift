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

import AsyncHTTPClient
import BaggageContext
import Instrumentation
import Logging
import NIO
import NIOHTTP1
import NIOInstrumentation

final class OrderServiceHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let httpClient: InstrumentedHTTPClient
    private let instrument: Instrument
    private let logger = Logger(label: "OrderService")

    init(httpClient: InstrumentedHTTPClient, instrument: Instrument) {
        self.httpClient = httpClient
        self.instrument = instrument
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard case .head(let requestHead) = self.unwrapInboundIn(data) else { return }

        var ctx = DefaultContext(baggage: .topLevel, logger: self.logger)

        self.instrument.extract(requestHead.headers, into: &ctx.baggage, using: HTTPHeadersExtractor())

        ctx.logger.info("🧾 Received order request")

        context.eventLoop.scheduleTask(in: .seconds(1)) {
            ctx.logger.info("🧾 Asking StorageService if your product exists")

            let request = try! HTTPClient.Request(url: "http://localhost:8081")
            self.httpClient.execute(request: request, context: ctx).whenComplete { _ in
                let responseHead = HTTPResponseHead(version: requestHead.version, status: .created)
                context.eventLoop.execute {
                    context.channel.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
                    context.channel.write(self.wrapOutboundOut(.end(nil)), promise: nil)
                    context.channel.flush()
                }
            }
        }
    }
}
