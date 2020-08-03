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
import OpenTelemetryInstrumentationSupport
import TracingInstrumentation
import XCTest

final class SpanAttributeSemanticsTests: XCTestCase {
    func testDynamicMemberLookup() {
        var attributes: SpanAttributes = [:]

        attributes.http.method = "GET"
        XCTAssertEqual(attributes.http.method, "GET")

        attributes.net.hostPort = 8080
        XCTAssertEqual(attributes.net.hostPort, 8080)

        attributes.peer.service = "hotrod"
        XCTAssertEqual(attributes.peer.service, "hotrod")

        attributes.endUser.id = "steve"
        XCTAssertEqual(attributes.endUser.id, "steve")
    }
}
