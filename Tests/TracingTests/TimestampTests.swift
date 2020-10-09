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

import Instrumentation
import Tracing
import XCTest

final class TimestampTests: XCTestCase {
    func test_timestamp_now() {
        let timestamp = Timestamp.now()
        XCTAssertGreaterThan(timestamp.microsSinceEpoch, 1_595_592_205_693_986)
        XCTAssertGreaterThan(timestamp.millisSinceEpoch, 1_595_592_205_693)
    }
}
