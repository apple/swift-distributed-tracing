//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Tracing
import XCTest

import struct Foundation.Date

@testable import Instrumentation

final class TracerTimeTests: XCTestCase {
    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }

    func testTracerTime() {
        let t = DefaultTracerClock.now
        let d = Date()
        XCTAssertEqual(
            Double(t.millisecondsSinceEpoch) / 1000,  // seconds
            d.timeIntervalSince1970,  // seconds
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
        let span: TestSpan = tracer.startSpan("start", at: mockClock.now)
        XCTAssertEqual(span.startTimestampNanosSinceEpoch, 13)
    }
}

final class MockClock {
    var _now: UInt64 = 0

    init() {}

    func setTime(_ time: UInt64) {
        self._now = time
    }

    struct Instant: TracerInstant {
        var nanosecondsSinceEpoch: UInt64
        static func < (lhs: MockClock.Instant, rhs: MockClock.Instant) -> Bool {
            lhs.nanosecondsSinceEpoch < rhs.nanosecondsSinceEpoch
        }
    }

    var now: Instant {
        Instant(nanosecondsSinceEpoch: self._now)
    }
}
