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

import Testing
import Tracing

import struct Foundation.Date

@testable import Instrumentation

@Suite("Tracer Time")
struct TracerTimeTests {
    @Test("DefaultTracerClock matches Date")
    func defaultTracerClockMatchesDate() {
        let t = DefaultTracerClock.now
        let d = Date()
        #expect(
            abs(Double(t.millisecondsSinceEpoch) / 1000 - d.timeIntervalSince1970) < 10
        )
    }

    @Test("Mock time with startSpan")
    func mockTimeStartSpan() {
        let tracer = TestTracer()

        let mockClock = MockClock()
        mockClock.setTime(13)
        let span: TestSpan = tracer.startSpan("start", at: mockClock.now)
        #expect(span.startTimestampNanosSinceEpoch == 13)
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
