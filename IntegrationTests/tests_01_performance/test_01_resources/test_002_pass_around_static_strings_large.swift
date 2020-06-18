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

func run(identifier: String) {
    measure(identifier: identifier) {
        var context = BaggageContext()
        // static allocated strings
        context[StringKey1.self] = String(repeating: "a", count: 30)
        context[StringKey2.self] = String(repeating: "b", count: 12)
        context[StringKey3.self] = String(repeating: "c", count: 20)

        var numberDone = 1
        for _ in 0..<1000 {
            let res = take1(context: context)
            precondition(res == 42)
            numberDone += 1
        }
        return 1
    }
}
