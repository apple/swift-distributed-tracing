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

import Baggage
import Instrumentation

/// No operation TracingInstrument, used when no tracing is required.
public struct NoOpTracingInstrument: TracingInstrument {
    public func startSpan(
        named operationName: String,
        context: BaggageContext,
        ofKind kind: SpanKind,
        at timestamp: Timestamp?
    ) -> Span {
        NoOpSpan()
    }

    public func inject<Carrier, Injector>(_ context: BaggageContext, into carrier: inout Carrier, using injector: Injector)
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier {}

    public func extract<Carrier, Extractor>(_ carrier: Carrier, into baggage: inout BaggageContext, using extractor: Extractor)
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier {}

    public struct NoOpSpan: Span {
        public var operationName: String = ""
        public var status: SpanStatus?
        public let kind: SpanKind = .internal

        public var startTimestamp: Timestamp {
            .now()
        }

        public var endTimestamp: Timestamp?

        public var baggage: BaggageContext {
            .init()
        }

        public mutating func addLink(_ link: SpanLink) {}

        public mutating func addEvent(_ event: SpanEvent) {}

        public var attributes: SpanAttributes {
            get {
                [:]
            }
            set {
                // ignore
            }
        }

        public let isRecording = false

        public mutating func end(at timestamp: Timestamp) {
            // ignore
        }
    }
}
