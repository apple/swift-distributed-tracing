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

import ContextPropagation
import XCTest

final class ContextTests: XCTestCase {
    func testMutations() {
        let traceID = UUID()
        var context = Context()
        XCTAssertNil(context.extract(TestTraceIDKey.self))

        context.inject(TestTraceIDKey.self, value: traceID)
        XCTAssertEqual(context.extract(TestTraceIDKey.self), traceID)

        context.remove(TestTraceIDKey.self)
        XCTAssertNil(context.extract(TestTraceIDKey.self))
    }
}

private enum TestTraceIDKey: ContextKey {
    typealias Value = UUID
}
