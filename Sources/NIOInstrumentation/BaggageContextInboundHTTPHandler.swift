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

public final class BaggageContextInboundHTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias InboundOut = HTTPServerRequestPart

    private let instrument: Instrument
    private var onBaggageExtracted: (BaggageContext) -> Void

    public init(instrument: Instrument, onBaggage: @escaping (BaggageContext) -> Void) {
        self.instrument = instrument
        self.onBaggageExtracted = onBaggage
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard case .head(let head) = unwrapInboundIn(data) else { return }
        var baggage = BaggageContext()
        self.instrument.extract(head.headers, into: &baggage, using: HTTPHeadersExtractor())
        self.onBaggageExtracted(baggage)
    }
}
