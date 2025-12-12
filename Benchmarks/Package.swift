// swift-tools-version: 5.9
//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
    name: "benchmarks",
    platforms: [
        .macOS("14")
    ],
    dependencies: [
        .package(path: "../"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.22.0"),
    ],
    targets: [
        .executableTarget(
            name: "TracingBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
            ],
            path: "Benchmarks/TracingBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        )
    ]
)
