//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift Distributed Tracing project
// authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Dispatch
@_exported import Instrumentation
@_exported import InstrumentationBaggage

/// Tracer that ignores all operations, used when no tracing is required.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
public struct NoOpTracer: LegacyTracer {
    public typealias TracerSpan = NoOpSpan

    public init() {}

    public func startAnySpan<Instant: TracerInstant>(_ operationName: String,
                                                     baggage: @autoclosure () -> Baggage,
                                                     ofKind kind: SpanKind,
                                                     at instant: @autoclosure () -> Instant,
                                                     function: String,
                                                     file fileID: String,
                                                     line: UInt) -> any Span
    {
        NoOpSpan(baggage: baggage())
    }

    public func forceFlush() {}

    public func inject<Carrier, Inject>(_ baggage: Baggage, into carrier: inout Carrier, using injector: Inject)
        where Inject: Injector, Carrier == Inject.Carrier
    {
        // no-op
    }

    public func extract<Carrier, Extract>(_ carrier: Carrier, into baggage: inout Baggage, using extractor: Extract)
        where Extract: Extractor, Carrier == Extract.Carrier
    {
        // no-op
    }

    public struct NoOpSpan: Span {
        public let baggage: Baggage
        public var isRecording: Bool {
            false
        }

        public var operationName: String {
            get {
                "noop"
            }
            nonmutating set {
                // ignore
            }
        }

        public init(baggage: Baggage) {
            self.baggage = baggage
        }

        public func setStatus(_ status: SpanStatus) {}

        public func addLink(_ link: SpanLink) {}

        public func addEvent(_ event: SpanEvent) {}

        public func recordError<Instant: TracerInstant>(_ error: Error, attributes: SpanAttributes, at instant: @autoclosure () -> Instant) {}

        public var attributes: SpanAttributes {
            get {
                [:]
            }
            nonmutating set {
                // ignore
            }
        }

        public func end<Instant: TracerInstant>(at instant: @autoclosure () -> Instant) {
            // ignore
        }
    }
}

#if swift(>=5.7.0)
extension NoOpTracer: Tracer {
    public func startSpan<Instant: TracerInstant>(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> NoOpSpan {
        NoOpSpan(baggage: baggage())
    }
}
#endif
