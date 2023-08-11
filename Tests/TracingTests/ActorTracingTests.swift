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

@testable @_spi(Locking) import Instrumentation
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
    let bar: LockedValueBox<Int> = .init(0)
    func foo() async {
        let num: LockedValueBox<Int> = .init(0)
        await withSpan(#function) { _ in
            self.bar.withValue { bar in
                bar += 1
            }
            await work()
            num.withValue { num in
                num += 1
            }
        }
    }
}
