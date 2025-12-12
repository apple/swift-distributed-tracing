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

import Benchmark
import Tracing

let benchmarks = {
    let defaultMetrics: [BenchmarkMetric] = [
        .mallocCountTotal
    ]

    Benchmark(
        "NoopTracing.startSpan_endSpan",
        configuration: .init(
            metrics: defaultMetrics,
            timeUnits: .nanoseconds,
            scalingFactor: .mega
        )
    ) { benchmark in
        let span = startSpan("name")
        defer { span.end() }
    }

    Benchmark(
        "NoopTracing.attribute. set, span.attributes['http.status_code'] = 200",
        configuration: .init(
            metrics: defaultMetrics,
            timeUnits: .nanoseconds,
            scalingFactor: .mega
        )
    ) { benchmark in
        let span = startSpan("name")
        span.attributes["http.status_code"] = 200
        defer { span.end() }
    }

    Benchmark(
        "NoopTracing.attribute. set, span.attributes.http.status_code = 200",
        configuration: .init(
            metrics: defaultMetrics,
            timeUnits: .nanoseconds,
            scalingFactor: .mega
        )
    ) { benchmark in
        let span = startSpan("name")
        span.attributes.http.statusCode = 200
        defer { span.end() }
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

extension SpanAttributes {
    var http: HTTPAttributes {
        get {
            .init(attributes: self)
        }
        set {
            self = newValue.attributes
        }
    }
}
