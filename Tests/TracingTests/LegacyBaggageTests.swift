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
import ServiceContextModule
import InstrumentationBaggage // legacy module, kept for easier migrations
import Tracing
import XCTest

final class ActorTracingTests: XCTestCase {
    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }
}

func test() {
    // Testing that the baggage type is just a typealias
    let baggage = Baggage.topLevel // import InstrumentationBaggage
    let span = startSpan("something", context: baggage)
}