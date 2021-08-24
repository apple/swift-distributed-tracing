//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2021 Apple Inc. and the Swift Distributed Tracing project
// authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
//
// Based on: https://github.com/apple/swift/tree/cf53143a47278c2a465409a67376642515956777/benchmark/utils
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
