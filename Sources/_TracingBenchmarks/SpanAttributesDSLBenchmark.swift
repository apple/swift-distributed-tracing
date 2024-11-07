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

@_spi(Locking) import Instrumentation
import Tracing
import _TracingBenchmarkTools

// swift-format-ignore: DontRepeatTypeInStaticProperties
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
enum DSLBenchmarks {
    public static let SpanAttributesDSLBenchmarks: [BenchmarkInfo] = [
        BenchmarkInfo(
            name: "SpanAttributesDSLBenchmarks.000_bench_empty",
            runFunction: { _ in try! bench_empty(times: 100) },
            tags: [],
            setUpFunction: { setUp() },
            tearDownFunction: { tearDown() }
        ),
        BenchmarkInfo(
            name: "SpanAttributesDSLBenchmarks.001_bench_makeSpan",
            runFunction: { _ in try! bench_makeSpan(times: 100) },
            tags: [],
            setUpFunction: { setUp() },
            tearDownFunction: { tearDown() }
        ),
        BenchmarkInfo(
            name: "SpanAttributesDSLBenchmarks.002_bench_startSpan_end",
            runFunction: { _ in try! bench_makeSpan(times: 100) },
            tags: [],
            setUpFunction: { setUp() },
            tearDownFunction: { tearDown() }
        ),

        BenchmarkInfo(
            name: "SpanAttributesDSLBenchmarks.00_bench_set_String_raw",
            runFunction: { _ in try! bench_set_String_raw(times: 100) },
            tags: [],
            setUpFunction: { setUp() },
            tearDownFunction: { tearDown() }
        ),
        BenchmarkInfo(
            name: "SpanAttributesDSLBenchmarks.01_bench_set_String_dsl",
            runFunction: { _ in try! bench_set_String_dsl(times: 100) },
            tags: [],
            setUpFunction: { setUp() },
            tearDownFunction: { tearDown() }
        ),

        BenchmarkInfo(
            name: "SpanAttributesDSLBenchmarks.02_bench_set_Int_raw",
            runFunction: { _ in try! bench_set_String_raw(times: 100) },
            tags: [],
            setUpFunction: { setUp() },
            tearDownFunction: { tearDown() }
        ),
        BenchmarkInfo(
            name: "SpanAttributesDSLBenchmarks.03_bench_set_Int_dsl",
            runFunction: { _ in try! bench_set_String_dsl(times: 100) },
            tags: [],
            setUpFunction: { setUp() },
            tearDownFunction: { tearDown() }
        ),
    ]

    fileprivate static let span: LockedValueBox<(any Tracing.Span)?> = .init(nil)

    fileprivate static func runTimesWithSpan(_ times: Int, work: (any Tracing.Span) -> Void) {
        self.span.withValue { span in
            for _ in 0..<times {
                work(span!)
            }
        }
    }

    fileprivate static func setUp() {
        self.span.withValue { span in
            span = InstrumentationSystem.legacyTracer.startAnySpan("something", context: .topLevel)
        }
    }

    fileprivate static func tearDown() {
        self.span.withValue { span in
            span = nil
        }
    }

    // ==== ----------------------------------------------------------------------------------------------------------------
    // MARK: make span

    static func bench_empty(times: Int) throws {}

    static func bench_makeSpan(times: Int) throws {
        for _ in 0..<times {
            let span = InstrumentationSystem.legacyTracer.startAnySpan("something", context: .topLevel)
            _ = span
        }
    }

    static func bench_startSpan_end(times: Int) throws {
        for _ in 0..<times {
            let span = InstrumentationSystem.legacyTracer.startAnySpan("something", context: .topLevel)
            span.end()
        }
    }

    // ==== ----------------------------------------------------------------------------------------------------------------
    // MARK: set String

    static func bench_set_String_raw(times: Int) throws {
        self.runTimesWithSpan(times) { span in
            span.attributes["http.method"] = "POST"
        }
    }

    static func bench_set_String_dsl(times: Int) throws {
        self.runTimesWithSpan(times) { span in
            span.attributes.http.method = "POST"
        }
    }

    // ==== ----------------------------------------------------------------------------------------------------------------
    // MARK: set Int

    static func bench_set_Int_raw(times: Int) throws {
        self.runTimesWithSpan(times) { span in
            span.attributes["http.status_code"] = 200
        }
    }

    static func bench_set_Int_dsl(times: Int) throws {
        self.runTimesWithSpan(times) { span in
            span.attributes.http.statusCode = 200
        }
    }

    @dynamicMemberLookup
    struct HTTPAttributes: SpanAttributeNamespace {
        var attributes: SpanAttributes

        init(attributes: SpanAttributes) {
            self.attributes = attributes
        }

        struct NestedSpanAttributes: NestedSpanAttributesProtocol {
            init() {}

            var method: Key<String> { "http.method" }
            var statusCode: Key<Int> { "http.status_code" }
        }
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
extension SpanAttributes {
    var http: DSLBenchmarks.HTTPAttributes {
        get {
            .init(attributes: self)
        }
        set {
            self = newValue.attributes
        }
    }
}
