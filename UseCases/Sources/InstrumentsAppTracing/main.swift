//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import BaggageContext
import Dispatch
import Instrumentation
import Tracing

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Setup
#if os(macOS) || os(tvOS) || os(iOS) || os(watchOS)

if #available(macOS 10.14, iOS 10.0, *) {
    let signpostTracing = OSSignpostTracingInstrument(
        subsystem: "org.swift.server.tracing.example",
        category: "Example",
        signpostName: "TracingSpans"
    )
    InstrumentationSystem.bootstrap(signpostTracing)
} else {
    fatalError("Available only on Apple platforms.")
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Manual usage

let tracer = InstrumentationSystem.tracer
let context = DefaultContext(baggage: .topLevel, logger: .init(label: "test"))

for i in 1 ... 5 {
    print("Starting operation: op-\(i)")
    let parentSpan = tracer.startSpan(named: "op-\(i)", baggage: context.baggage)
    defer { parentSpan.end() }

    DispatchQueue.global().async {
        let span = tracer.startSpan(named: "op-\(i)-inner", baggage: context.baggage)
        span.addLink(parentSpan)
        print("    Starting sub-operation: op-\(i)-inner")
        defer { span.end() }

        sleep(UInt32(1))
    }
    // TODO: Thread.run { let some child span here }

    sleep(UInt32(i))
}

print("done.")

#else
print("Demo only available on macOS / Apple platforms.")

#endif
