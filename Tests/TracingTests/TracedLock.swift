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

import Foundation
import Instrumentation
import ServiceContextModule
import Tracing

/// Marked as @unchecked Sendable due to the synchronization being
/// performed manually using locks.
final class TracedLock: @unchecked Sendable {
    private let name: String
    private let underlyingLock: NSLock

    private var activeSpan: (any Tracing.Span)?

    init(name: String) {
        self.name = name
        self.underlyingLock = NSLock()
    }

    func lock(context: ServiceContext) {
        // time here
        self.underlyingLock.lock()
        self.activeSpan = InstrumentationSystem.legacyTracer.startAnySpan(self.name, context: context)
    }

    func unlock(context: ServiceContext) {
        self.activeSpan?.end()
        self.activeSpan = nil
        self.underlyingLock.unlock()
    }

    func withLock(context: ServiceContext, _ closure: () -> Void) {
        self.lock(context: context)
        defer { self.unlock(context: context) }
        closure()
    }
}
