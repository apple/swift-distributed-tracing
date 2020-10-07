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

final class HTTPHeadersInjectingHandlerTests: XCTestCase {
    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }

    func test_injects_baggage_into_http_request_headers() throws {
        InstrumentationSystem.bootstrapInternal(FakeTracer())

        let traceID = "abc"

        var baggage = Baggage.topLevel
        baggage[FakeTracer.TraceIDKey.self] = traceID

        let httpVersion = HTTPVersion(major: 1, minor: 1)
        let handler = HTTPHeadersInjectingHandler()
        let loop = EmbeddedEventLoop()
        let channel = EmbeddedChannel(handler: handler, loop: loop)
        channel._channelCore.baggage = baggage
        let requestHead = HTTPRequestHead(version: httpVersion, method: .GET, uri: "/")

        try channel.writeOutbound(HTTPClientRequestPart.head(requestHead))
        let modifiedRequestPart = try channel.readOutbound(as: HTTPClientRequestPart.self)

        XCTAssertEqual(
            modifiedRequestPart,
            .head(.init(version: httpVersion, method: .GET, uri: "/", headers: [FakeTracer.headerName: traceID]))
        )
    }
}
