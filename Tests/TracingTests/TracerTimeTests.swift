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

import InstrumentationBaggage
import Tracing
import struct Foundation.Date
import XCTest

final class TracerTimeTests: XCTestCase {
    func testTracerTime() {
        let t = TracerClock.now
        let d = Date()
        XCTAssertEqual(
            (Double(t.millisSinceEpoch) / 1000), // seconds
            d.timeIntervalSince1970,  // seconds
            accuracy: 10)
    }
}