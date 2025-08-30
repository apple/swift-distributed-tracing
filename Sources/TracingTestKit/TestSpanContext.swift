//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ServiceContextModule

public struct TestSpanContext: Sendable, Hashable {
    public let traceID: String
    public let spanID: String
    public let parentSpanID: String?

    public init(traceID: String, spanID: String, parentSpanID: String?) {
        self.traceID = traceID
        self.spanID = spanID
        self.parentSpanID = parentSpanID
    }
}

extension ServiceContext {
    var testSpanContext: TestSpanContext? {
        get {
            self[TestSpanContextKey.self]
        }
        set {
            self[TestSpanContextKey.self] = newValue
        }
    }
}

private struct TestSpanContextKey: ServiceContextKey {
    typealias Value = TestSpanContext
}
