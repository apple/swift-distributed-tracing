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

import Instrumentation
import InstrumentationBaggage
import Tracing
import XCTest

#if swift(>=5.7.0)
// Specifically make sure we don't have to implement startAnySpan

final class SampleSwift57Tracer: Tracer {
    private(set) var spans = [SampleSwift57Span]()
    var onEndSpan: (SampleSwift57Span) -> Void = { _ in }

    func startSpan<Instant: TracerInstant>(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> SampleSwift57Span {
        let span = SampleSwift57Span(
            operationName: operationName,
            startTime: instant(),
            baggage: baggage(),
            kind: kind,
            onEnd: self.onEndSpan
        )
        self.spans.append(span)
        return span
    }

    public func forceFlush() {}

    func extract<Carrier, Extract>(_ carrier: Carrier, into baggage: inout Baggage, using extractor: Extract)
        where
        Extract: Extractor,
        Carrier == Extract.Carrier
    {}

    func inject<Carrier, Inject>(_ baggage: Baggage, into carrier: inout Carrier, using injector: Inject)
        where
        Inject: Injector,
        Carrier == Inject.Carrier
    {}
}

/// Only intended to be used in single-threaded SampleSwift57ing.
final class SampleSwift57Span: Span {
    private let kind: SpanKind

    private var status: SpanStatus?

    public let startTimeNanoseconds: UInt64
    public private(set) var endTimeNanoseconds: UInt64?

    private(set) var recordedErrors: [(Error, SpanAttributes)] = []

    var operationName: String
    let baggage: Baggage

    private(set) var events = [SpanEvent]() {
        didSet {
            self.isRecording = !self.events.isEmpty
        }
    }

    private(set) var links = [SpanLink]()

    var attributes: SpanAttributes = [:] {
        didSet {
            self.isRecording = !self.attributes.isEmpty
        }
    }

    private(set) var isRecording = false

    let onEnd: (SampleSwift57Span) -> Void

    init<Instant: TracerInstant>(
        operationName: String,
        startTime: Instant,
        baggage: Baggage,
        kind: SpanKind,
        onEnd: @escaping (SampleSwift57Span) -> Void
    ) {
        self.operationName = operationName
        self.startTimeNanoseconds = startTime.nanosecondsSinceEpoch
        self.baggage = baggage
        self.onEnd = onEnd
        self.kind = kind
    }

    func setStatus(_ status: SpanStatus) {
        self.status = status
        self.isRecording = true
    }

    func addLink(_ link: SpanLink) {
        self.links.append(link)
    }

    func addEvent(_ event: SpanEvent) {
        self.events.append(event)
    }

    func recordError<Instant: TracerInstant>(_ error: Error, attributes: SpanAttributes, at instant: @autoclosure () -> Instant) {
        self.recordedErrors.append((error, attributes))
    }

    func end<Instant: TracerInstant>(at instant: Instant) {
        self.endTimeNanoseconds = instant.nanosecondsSinceEpoch
        self.onEnd(self)
    }
}

extension SampleSwift57Tracer: @unchecked Sendable {} // only intended for single threaded SampleSwift57ing
extension SampleSwift57Span: @unchecked Sendable {} // only intended for single threaded SampleSwift57ing

#endif
