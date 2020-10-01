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
import NIOInstrumentation
import XCTest

final class BaggageContextInboundHTTPHandlerTests: XCTestCase {
    func testForwardsHTTPHeadersToInstrumentationMiddleware() throws {
        let traceID = "abc"
        let callbackExpectation = expectation(description: "Expected onBaggageExtracted to be called")

        var extractedBaggage: Baggage?
        let handler = BaggageContextInboundHTTPHandler(instrument: FakeTracer()) { baggage in
            extractedBaggage = baggage
            callbackExpectation.fulfill()
        }
        let loop = EmbeddedEventLoop()
        let channel = EmbeddedChannel(handler: handler, loop: loop)
        var requestHead = HTTPRequestHead(version: .init(major: 1, minor: 1), method: .GET, uri: "/")
        requestHead.headers = [FakeTracer.headerName: traceID]

        try channel.writeInbound(HTTPServerRequestPart.head(requestHead))

        waitForExpectations(timeout: 0.5)

        XCTAssertNotNil(extractedBaggage)
        XCTAssertEqual(extractedBaggage![FakeTracer.TraceIDKey.self], traceID)
    }
}
