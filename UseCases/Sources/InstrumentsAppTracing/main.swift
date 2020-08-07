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
import Dispatch
import Instrumentation
import TracingInstrumentation

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

let tracer = InstrumentationSystem.tracingInstrument
let context = BaggageContext()

for i in 1 ... 5 {
    print("Starting operation: op-\(i)")
    var parentSpan = tracer.startSpan(named: "op-\(i)", context: context)
    defer { parentSpan.end() }

    DispatchQueue.global().async {
        var span = tracer.startSpan(named: "op-\(i)-inner", context: BaggageContext()) // empty context
        span.addLink(SpanLink(context: parentSpan.context)) // TODO: span.addLink(parentSpan)
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
