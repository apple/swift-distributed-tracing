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
@testable import Instrumentation
import NIO
import NIOHTTP1
import NIOInstrumentation
import XCTest

final class HeaderExtractingHTTPServerHandlerTests: XCTestCase {
    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }

    func test_extracts_http_request_headers_into_baggage() throws {
        InstrumentationSystem.bootstrapInternal(FakeTracer())

        let traceID = "abc"
        let handler = HeaderExtractingHTTPServerHandler()
        let loop = EmbeddedEventLoop()
        let channel = EmbeddedChannel(handler: handler, loop: loop)

        var requestHead = HTTPRequestHead(version: .init(major: 1, minor: 1), method: .GET, uri: "/")
        requestHead.headers = [FakeTracer.headerName: traceID]

        XCTAssertNil(channel._channelCore.baggage[FakeTracer.TraceIDKey.self])

        try channel.writeInbound(HTTPServerRequestPart.head(requestHead))

        XCTAssertEqual(channel._channelCore.baggage[FakeTracer.TraceIDKey.self], traceID)
    }

    func test_forwards_all_read_events() throws {
        InstrumentationSystem.bootstrapInternal(FakeTracer())

        let channel = EmbeddedChannel(loop: EmbeddedEventLoop())
        try channel.pipeline.addHandlers(HeaderExtractingHTTPServerHandler()).wait()

        let requestHead = HTTPRequestHead(version: .init(major: 1, minor: 1), method: .GET, uri: "/")
        try channel.writeInbound(HTTPServerRequestPart.head(requestHead))
        XCTAssertNotNil(try channel.readInbound(as: HTTPServerRequestPart.self))

        try channel.writeInbound(HTTPServerRequestPart.body(channel.allocator.buffer(string: "Test")))
        XCTAssertNotNil(try channel.readInbound(as: HTTPServerRequestPart.self))

        try channel.writeInbound(HTTPServerRequestPart.end(nil))
        XCTAssertNotNil(try channel.readInbound(as: HTTPServerRequestPart.self))
    }
}
