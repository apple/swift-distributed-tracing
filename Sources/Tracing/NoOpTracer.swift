//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_exported import Baggage
@_exported import Instrumentation

/// No operation Tracer, used when no tracing is required.
public struct NoOpTracer: Tracer {
    public func startSpan(
        _ operationName: String,
        baggage: Baggage,
        ofKind kind: SpanKind,
        at timestamp: Timestamp
    ) -> Span {
        return NoOpSpan(baggage: baggage)
    }

    public func forceFlush() {}

    public func inject<Carrier, Inject>(_ baggage: Baggage, into carrier: inout Carrier, using injector: Inject)
        where Inject: Injector, Carrier == Inject.Carrier {
        // no-op
    }

    public func extract<Carrier, Extract>(_ carrier: Carrier, into baggage: inout Baggage, using extractor: Extract)
        where Extract: Extractor, Carrier == Extract.Carrier {
        // no-op
    }

    public final class NoOpSpan: Span {
        public let baggage: Baggage
        public let isRecording = false

        public init(baggage: Baggage) {
            self.baggage = baggage
        }

        public func setStatus(_ status: SpanStatus) {}

        public func addLink(_ link: SpanLink) {}

        public func addEvent(_ event: SpanEvent) {}

        public func recordError(_ error: Error) {}

        public var attributes: SpanAttributes {
            get {
                return [:]
            }
            set {
                // ignore
            }
        }

        public func end(at timestamp: Timestamp) {
            // ignore
        }
    }
}
