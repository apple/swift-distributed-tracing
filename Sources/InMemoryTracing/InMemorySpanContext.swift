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

/// A type that encapsulates the trace ID, span ID, and parent span ID of an in-memory span.
///
/// Generally used through the `ServiceContext/inMemorySpanContext` task local value.
public struct InMemorySpanContext: Sendable, Hashable {
    /// The idenfifier of top-level trace of which this span is a part of.
    public var traceID: String

    /// The identifier of this span.
    public var spanID: String

    /// The Identifier of the parent of this span, if any.
    public var parentSpanID: String?

    /// Creates a new in-memory span context.
    /// - Parameters:
    ///   - traceID: The trace ID for the context.
    ///   - spanID: The span ID for the context.
    ///   - parentSpanID: The context's parent span ID.
    public init(traceID: String, spanID: String, parentSpanID: String?) {
        self.traceID = traceID
        self.spanID = spanID
        self.parentSpanID = parentSpanID
    }
}

extension ServiceContext {
    /// A task-local value that represents the current tracing span as set by the in-memory tracer.
    public var inMemorySpanContext: InMemorySpanContext? {
        get {
            self[InMemorySpanContextKey.self]
        }
        set {
            self[InMemorySpanContextKey.self] = newValue
        }
    }
}

private struct InMemorySpanContextKey: ServiceContextKey {
    typealias Value = InMemorySpanContext
}
