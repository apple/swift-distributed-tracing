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
import Instrumentation
import NIO
import NIOHTTP1

public final class HTTPHeadersInjectingHandler: ChannelOutboundHandler {
    public typealias OutboundIn = HTTPClientRequestPart
    public typealias OutboundOut = HTTPClientRequestPart

    public init() {}

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let requestPart = unwrapOutboundIn(data)
        guard case .head(var head) = requestPart else { return }
        InstrumentationSystem.instrument.inject(context.baggage, into: &head.headers, using: HTTPHeadersInjector())
        context.write(self.wrapOutboundOut(.head(head)), promise: promise)
    }
}
