//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import Instrumentation
import Tracing
import XCTest

final class TracingInstrumentationSystemTests: XCTestCase {
    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }

    func testItProvidesAccessToATracer() {
        let tracer = TestTracer()

        XCTAssertNil(InstrumentationSystem.tracer(of: TestTracer.self))

        InstrumentationSystem.bootstrapInternal(tracer)
        XCTAssertFalse(InstrumentationSystem.instrument is MultiplexInstrument)
        XCTAssert(InstrumentationSystem.instrument(of: TestTracer.self) === tracer)
        XCTAssertNil(InstrumentationSystem.instrument(of: NoOpInstrument.self))

        XCTAssert(InstrumentationSystem.tracer(of: TestTracer.self) === tracer)
        XCTAssert(InstrumentationSystem.tracer is TestTracer)

        let multiplexInstrument = MultiplexInstrument([tracer])
        InstrumentationSystem.bootstrapInternal(multiplexInstrument)
        XCTAssert(InstrumentationSystem.instrument is MultiplexInstrument)
        XCTAssert(InstrumentationSystem.instrument(of: TestTracer.self) === tracer)

        XCTAssert(InstrumentationSystem.tracer(of: TestTracer.self) === tracer)
        XCTAssert(InstrumentationSystem.tracer is TestTracer)
    }
}
