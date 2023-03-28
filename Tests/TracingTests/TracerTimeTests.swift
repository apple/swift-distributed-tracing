//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2021 Apple Inc. and the Swift Distributed Tracing project
// authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Foundation.Date
@testable import Instrumentation
import Tracing
import XCTest

final class TracerTimeTests: XCTestCase {
    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }

    func testTracerTime() {
        let t = TracerClock.now
        let d = Date()
        XCTAssertEqual(
            Double(t.millisSinceEpoch) / 1000, // seconds
            d.timeIntervalSince1970, // seconds
            accuracy: 10
        )
    }

    func testMockTimeStartSpan() {
        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(NoOpTracer())
        }

        let mockClock = MockClock()
        mockClock.setTime(13)
        let span: TestSpan = tracer.startSpan("start", clock: mockClock)
        XCTAssertEqual(span.startTime, 13)
    }
}

final class MockClock: TracerClockProtocol {
    var _now: UInt64 = 0

    init() {}

    func setTime(_ time: UInt64) {
        self._now = time
    }

    struct Instant: TracerInstantProtocol {
        var millisSinceEpoch: UInt64
        static func < (lhs: MockClock.Instant, rhs: MockClock.Instant) -> Bool {
            lhs.millisSinceEpoch < rhs.millisSinceEpoch
        }
    }

    var now: Instant {
        Instant(millisSinceEpoch: self._now)
    }
}
