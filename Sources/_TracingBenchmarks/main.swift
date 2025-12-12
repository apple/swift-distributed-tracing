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

import _TracingBenchmarkTools

assert(
    {
        print("===========================================================================")
        print("=          !!  YOU ARE RUNNING BENCHMARKS IN DEBUG MODE  !!               =")
        print("=     When running on the command line, use: `swift run -c release`       =")
        print("===========================================================================")
        return true
    }()
)

@inline(__always)
private func registerBenchmark(_ bench: BenchmarkInfo) {
    internalRegisterBenchmark(bench)
}

@inline(__always)
private func registerBenchmark(_ benches: [BenchmarkInfo]) {
    benches.forEach(registerBenchmark)
}

@inline(__always)
private func registerBenchmark(
    _ name: String,
    _ function: @escaping @Sendable (Int) -> Void,
    _ tags: [BenchmarkCategory]
) {
    registerBenchmark(BenchmarkInfo(name: name, runFunction: function, tags: tags))
}

if #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) {  // for TaskLocal ServiceContext
    registerBenchmark(DSLBenchmarks.SpanAttributesDSLBenchmarks)
    main()
}
