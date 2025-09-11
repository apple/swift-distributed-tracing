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

/// Encapsulates the `traceID`, `spanID` and `parentSpanID` of an `InMemorySpan`.
/// Generally used through the `ServiceContext/inMemorySpanContext` task local value.
public struct InMemorySpanContext: Sendable, Hashable {
    /// Idenfifier of top-level trace of which this span is a part of.
    public let traceID: String

    /// Identifier of this specific span.
    public let spanID: String

    // Identifier of the parent of this span, if any.
    public let parentSpanID: String?

    public init(traceID: String, spanID: String, parentSpanID: String?) {
        self.traceID = traceID
        self.spanID = spanID
        self.parentSpanID = parentSpanID
    }
}

extension ServiceContext {
    /// Task-local value representing the current tracing ``Span`` as set by the ``InMemoryTracer``.
    public var inMemorySpanContext: InMemorySpanContext? {
        get {
            self[InMemorySpanContextKey.self]
        }
        set {
            self[InMemorySpanContextKey.self] = newValue
        }
    }
}

struct InMemorySpanContextKey: ServiceContextKey {
    typealias Value = InMemorySpanContext
}
