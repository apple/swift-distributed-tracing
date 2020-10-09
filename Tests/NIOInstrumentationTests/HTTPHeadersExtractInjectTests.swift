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

@testable import Instrumentation
import NIO
import NIOHTTP1
import NIOInstrumentation
import XCTest

final class HTTPHeadersExtractInjectTests: XCTestCase {
    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }

    func test_extracted_baggage_into_subsequent_request_headers() throws {
        InstrumentationSystem.bootstrapInternal(FakeTracer())

        let outboundHandler = HeaderInjectingHTTPClientHandler()
        let requestHandler = MockRequestHandler()
        let inboundHandler = HeaderExtractingHTTPServerHandler()

        let channel = EmbeddedChannel(loop: EmbeddedEventLoop())
        XCTAssertNoThrow(try channel.pipeline.addHandlers([outboundHandler, requestHandler, inboundHandler]).wait())

        let requestHead = HTTPRequestHead(version: .init(major: 1, minor: 1), method: .GET, uri: "/", headers: [
            FakeTracer.headerName: "abc",
        ])
        try channel.writeInbound(HTTPServerRequestPart.head(requestHead))

        guard case .head(let subsequentRequestHead)? = try channel.readOutbound(as: HTTPClientRequestPart.self) else {
            XCTFail("Expected HTTPRequestHead to be written outbound")
            return
        }
        XCTAssertEqual(subsequentRequestHead.headers.count, 2)
        XCTAssertEqual(subsequentRequestHead.headers.first(name: "Content-Type"), "application/json")
        XCTAssertEqual(subsequentRequestHead.headers.first(name: FakeTracer.headerName), "abc")
    }
}

private final class MockRequestHandler: ChannelDuplexHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundIn = HTTPClientRequestPart
    typealias OutboundOut = HTTPClientRequestPart

    func channelReadComplete(context: ChannelHandlerContext) {
        let requestHead = HTTPRequestHead(version: .init(major: 1, minor: 1), method: .GET, uri: "/", headers: [
            "Content-Type": "application/json",
        ])
        context.writeAndFlush(wrapOutboundOut(.head(requestHead)), promise: nil)
    }
}
