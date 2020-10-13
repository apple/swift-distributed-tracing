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
import Instrumentation
import Logging
import NIO
import NIOHTTP1
import NIOInstrumentation

final class StorageServiceHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let logger = Logger(label: "StorageService")
    private let instrument: Instrument

    init(instrument: Instrument) {
        self.instrument = instrument
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard case .head(let requestHead) = self.unwrapInboundIn(data) else { return }

        var ctx = DefaultContext(baggage: .topLevel, logger: logger)
        self.instrument.extract(requestHead.headers, into: &ctx.baggage, using: HTTPHeadersExtractor())

        ctx.logger.info("📦 Looking for the product")

        context.eventLoop.scheduleTask(in: .seconds(2)) {
            ctx.logger.info("📦 Found the product")
            let responseHead = HTTPResponseHead(version: requestHead.version, status: .ok)
            context.eventLoop.execute {
                context.channel.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
                context.channel.write(self.wrapOutboundOut(.end(nil)), promise: nil)
                context.channel.flush()
            }
        }
    }
}
