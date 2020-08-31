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

import Baggage
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

    func lock(context: BaggageContext) {
        // time here
        self.underlyingLock.lock()
        self.activeSpan = InstrumentationSystem.tracingInstrument.startSpan(named: self.name, context: context)
    }

    func unlock(context: BaggageContext) {
        self.activeSpan?.end()
        self.activeSpan = nil
        self.underlyingLock.unlock()
    }

    func withLock(context: BaggageContext, _ closure: () -> Void) {
        self.lock(context: context)
        defer { self.unlock(context: context) }
        closure()
    }
}
