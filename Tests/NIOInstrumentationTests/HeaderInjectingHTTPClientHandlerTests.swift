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
@testable import Instrumentation
import NIO
import NIOHTTP1
import NIOInstrumentation
import XCTest

final class HeaderInjectingHTTPClientHandlerTests: XCTestCase {
    private let httpVersion = HTTPVersion(major: 1, minor: 1)

    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }

    func test_injects_baggage_into_http_request_headers() throws {
        InstrumentationSystem.bootstrapInternal(FakeTracer())

        let traceID = "abc"

        var baggage = Baggage.topLevel
        baggage[FakeTracer.TraceIDKey.self] = traceID

        let handler = HeaderInjectingHTTPClientHandler()
        let loop = EmbeddedEventLoop()
        let channel = EmbeddedChannel(handler: handler, loop: loop)
        channel._channelCore.baggage = baggage
        let requestHead = HTTPRequestHead(version: httpVersion, method: .GET, uri: "/")

        try channel.writeOutbound(HTTPClientRequestPart.head(requestHead))

        XCTAssertEqual(
            try channel.readOutbound(as: HTTPClientRequestPart.self),
            .head(.init(version: self.httpVersion, method: .GET, uri: "/", headers: [FakeTracer.headerName: traceID]))
        )
    }

    func test_forwards_all_write_events() throws {
        let channel = EmbeddedChannel(
            handler: HeaderInjectingHTTPClientHandler(),
            loop: EmbeddedEventLoop()
        )

        let requestHead = HTTPRequestHead(version: httpVersion, method: .GET, uri: "/")
        let head = HTTPClientRequestPart.head(requestHead)
        try channel.writeOutbound(head)
        XCTAssertEqual(try channel.readOutbound(), head)

        let body = HTTPClientRequestPart.body(.byteBuffer(channel.allocator.buffer(string: "test")))
        try channel.writeOutbound(body)
        XCTAssertEqual(try channel.readOutbound(), body)

        let end = HTTPClientRequestPart.end(nil)
        try channel.writeOutbound(end)
        XCTAssertEqual(try channel.readOutbound(), end)
    }
}
