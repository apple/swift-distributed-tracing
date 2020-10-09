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

public final class HeaderInjectingHTTPClientHandler: ChannelOutboundHandler {
    public typealias OutboundIn = HTTPClientRequestPart
    public typealias OutboundOut = HTTPClientRequestPart

    public init() {}

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        guard case .head(var head) = self.unwrapOutboundIn(data) else {
            context.write(data, promise: promise)
            return
        }

        InstrumentationSystem.instrument.inject(context.baggage, into: &head.headers, using: HTTPHeadersInjector())
        context.write(self.wrapOutboundOut(.head(head)), promise: promise)
    }
}
