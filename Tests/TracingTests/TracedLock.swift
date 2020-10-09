//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020 Moritz Lang and the Swift Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import BaggageContext
import Foundation
import Instrumentation
import Tracing

final class TracedLock {
    let name: String
    let underlyingLock: NSLock

    var activeSpan: Span?

    init(name: String) {
        self.name = name
        self.underlyingLock = NSLock()
    }

    func lock(baggage: Baggage) {
        // time here
        self.underlyingLock.lock()
        self.activeSpan = InstrumentationSystem.tracer.startSpan(named: self.name, baggage: baggage)
    }

    func unlock(baggage: Baggage) {
        self.activeSpan?.end()
        self.activeSpan = nil
        self.underlyingLock.unlock()
    }

    func withLock(baggage: Baggage, _ closure: () -> Void) {
        self.lock(baggage: baggage)
        defer { self.unlock(baggage: baggage) }
        closure()
    }
}
