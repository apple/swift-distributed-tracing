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

#if swift(>=5.2)

import _TracingBenchmarkTools
import Tracing
import TracingOpenTelemetrySupport

public let SpanAttributesDSLBenchmarks: [BenchmarkInfo] = [
    BenchmarkInfo(
        name: "SpanAttributesDSLBenchmarks.000_bench_empty",
        runFunction: { _ in try! bench_empty(times: 100) },
        tags: [],
        setUpFunction: { setUp() },
        tearDownFunction: tearDown
    ),
    BenchmarkInfo(
        name: "SpanAttributesDSLBenchmarks.001_bench_makeSpan",
        runFunction: { _ in try! bench_makeSpan(times: 100) },
        tags: [],
        setUpFunction: { setUp() },
        tearDownFunction: tearDown
    ),
    BenchmarkInfo(
        name: "SpanAttributesDSLBenchmarks.002_bench_startSpan_end",
        runFunction: { _ in try! bench_makeSpan(times: 100) },
        tags: [],
        setUpFunction: { setUp() },
        tearDownFunction: tearDown
    ),

    BenchmarkInfo(
        name: "SpanAttributesDSLBenchmarks.00_bench_set_String_raw",
        runFunction: { _ in try! bench_set_String_raw(times: 100) },
        tags: [],
        setUpFunction: { setUp() },
        tearDownFunction: tearDown
    ),
    BenchmarkInfo(
        name: "SpanAttributesDSLBenchmarks.01_bench_set_String_dsl",
        runFunction: { _ in try! bench_set_String_dsl(times: 100) },
        tags: [],
        setUpFunction: { setUp() },
        tearDownFunction: tearDown
    ),

    BenchmarkInfo(
        name: "SpanAttributesDSLBenchmarks.02_bench_set_Int_raw",
        runFunction: { _ in try! bench_set_String_raw(times: 100) },
        tags: [],
        setUpFunction: { setUp() },
        tearDownFunction: tearDown
    ),
    BenchmarkInfo(
        name: "SpanAttributesDSLBenchmarks.03_bench_set_Int_dsl",
        runFunction: { _ in try! bench_set_String_dsl(times: 100) },
        tags: [],
        setUpFunction: { setUp() },
        tearDownFunction: tearDown
    ),
]

private var context: LoggingContext!
private var span: Span!

private func setUp() {
    context = DefaultLoggingContext.topLevel(logger: .init(label: ""))
    span = InstrumentationSystem.tracer.startSpan("something", context: context)
}

private func tearDown() {
    context = nil
    span = nil
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: make span

func bench_empty(times: Int) throws {}

func bench_makeSpan(times: Int) throws {
    for _ in 0 ..< times {
        let span = InstrumentationSystem.tracer.startSpan("something", context: context)
        _ = span
    }
}

func bench_startSpan_end(times: Int) throws {
    for _ in 0 ..< times {
        let span = InstrumentationSystem.tracer.startSpan("something", context: context)
        span.end()
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: set String

func bench_set_String_raw(times: Int) throws {
    for _ in 0 ..< times {
        span.attributes["http.method"] = "POST"
    }
}

func bench_set_String_dsl(times: Int) throws {
    for _ in 0 ..< times {
        span.attributes.http.method = "POST"
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: set Int

func bench_set_Int_raw(times: Int) throws {
    for _ in 0 ..< times {
        span.attributes["http.status_code"] = 200
    }
}

func bench_set_Int_dsl(times: Int) throws {
    for _ in 0 ..< times {
        span.attributes.http.statusCode = 200
    }
}

#endif
