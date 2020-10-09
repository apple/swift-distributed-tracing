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

import Baggage
import Instrumentation
import NIO
import NIOHTTP1

import Baggage
import Instrumentation
import NIO
import NIOHTTP1

public final class HeaderExtractingHTTPServerHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias InboundOut = HTTPServerRequestPart

    public init() {}

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        if case .head(let head) = self.unwrapInboundIn(data) {
            InstrumentationSystem.instrument.extract(
                head.headers,
                into: &context.baggage,
                using: HTTPHeadersExtractor()
            )
        }

        context.fireChannelRead(data)
    }
}
