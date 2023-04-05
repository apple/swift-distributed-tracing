//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift Distributed Tracing project
// authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import Instrumentation
import InstrumentationBaggage
import Tracing
import XCTest


final class TracedTests: XCTestCase {

    @traced func _hello() async -> String { "Hello" }
//    @traced func hello() async -> String { "Hello" }

    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }

    func testTracedMacro() async {
        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(NoOpTracer())
        }

        await hello()

        XCTAssertEqual(tracer.spans.count, 1)
        for span in tracer.spans {
            XCTAssertEqual(span.operationName, "_hello()")
        }
    }
}