//===----------------------------------------------------------------------===//
//
// This source file is part of the GSoC Swift Distributed Tracing open source project
// Based on: https://github.com/apple/swift/tree/cf53143a47278c2a465409a67376642515956777/benchmark/utils
//
// Copyright (c) 2020 Apple Inc. and the GSoC Swift Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of GSoC Swift Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

public enum BenchmarkCategory: String {

    // Most benchmarks are assumed to be "stable" and will be regularly tracked at
    // each commit. A handful may be marked unstable if continually tracking them is
    // counterproductive.
    case unstable

    // Explicit skip marker
    case skip
}
