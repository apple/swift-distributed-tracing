//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2019 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Baggage
import Foundation

@inline(never)
func take1(context: BaggageContext) -> Int {
    take2(context: context)
}

@inline(never)
func take2(context: BaggageContext) -> Int {
    take3(context: context)
}

@inline(never)
func take3(context: BaggageContext) -> Int {
    take4(context: context)
}

@inline(never)
func take4(context: BaggageContext) -> Int {
    42
}

enum StringKey1: BaggageContextKey {
    typealias Value = String
}

enum StringKey2: BaggageContextKey {
    typealias Value = String
}

enum StringKey3: BaggageContextKey {
    typealias Value = String
}
