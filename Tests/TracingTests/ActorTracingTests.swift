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
import Tracing
import XCTest

final class ActorTracingTests: XCTestCase {
    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }
}

func work() async {}

actor Foo {
    var bar = 0
    func foo() async {
        var num = 0
        await withSpan(#function) { _ in
            bar += 1
            await work()
            num += 1
        }
    }
}
