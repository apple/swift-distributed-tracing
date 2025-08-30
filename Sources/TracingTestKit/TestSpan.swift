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

@_spi(Locking) import Instrumentation
import Tracing

public struct TestSpan: Span {
    public let context: ServiceContext
    public let spanContext: TestSpanContext
    public let startInstant: any TracerInstant

    init(
        operationName: String,
        context: ServiceContext,
        spanContext: TestSpanContext,
        startInstant: any TracerInstant,
        onEnd: @escaping @Sendable (FinishedTestSpan) -> Void
    ) {
        self._operationName = LockedValueBox(operationName)
        self.context = context
        self.spanContext = spanContext
        self.startInstant = startInstant
        self.onEnd = onEnd
    }

    public var isRecording: Bool {
        _isRecording.withValue(\.self)
    }

    public var operationName: String {
        get {
            _operationName.withValue(\.self)
        }
        nonmutating set {
            assertIsRecording()
            _operationName.withValue { $0 = newValue }
        }
    }

    public var attributes: SpanAttributes {
        get {
            _attributes.withValue(\.self)
        }
        nonmutating set {
            assertIsRecording()
            _attributes.withValue { $0 = newValue }
        }
    }

    public var events: [SpanEvent] {
        _events.withValue(\.self)
    }

    public func addEvent(_ event: SpanEvent) {
        assertIsRecording()
        _events.withValue { $0.append(event) }
    }

    public var links: [SpanLink] {
        _links.withValue(\.self)
    }

    public func addLink(_ link: SpanLink) {
        assertIsRecording()
        _links.withValue { $0.append(link) }
    }

    public var errors: [RecordedError] {
        _errors.withValue(\.self)
    }

    public func recordError(
        _ error: any Error,
        attributes: SpanAttributes,
        at instant: @autoclosure () -> some TracerInstant
    ) {
        assertIsRecording()
        _errors.withValue {
            $0.append(RecordedError(error: error, attributes: attributes, instant: instant()))
        }
    }

    public var status: SpanStatus? {
        _status.withValue(\.self)
    }

    public func setStatus(_ status: SpanStatus) {
        assertIsRecording()
        _status.withValue { $0 = status }
    }

    public func end(at instant: @autoclosure () -> some TracerInstant) {
        assertIsRecording()
        let finishedSpan = FinishedTestSpan(
            operationName: operationName,
            context: context,
            spanContext: spanContext,
            startInstant: startInstant,
            endInstant: instant(),
            attributes: attributes,
            events: events,
            links: links,
            errors: errors,
            status: status
        )
        _isRecording.withValue { $0 = false }
        onEnd(finishedSpan)
    }

    public struct RecordedError: Sendable {
        public let error: Error
        public let attributes: SpanAttributes
        public let instant: any TracerInstant
    }

    private let _operationName: LockedValueBox<String>
    private let _attributes = LockedValueBox<SpanAttributes>([:])
    private let _events = LockedValueBox<[SpanEvent]>([])
    private let _links = LockedValueBox<[SpanLink]>([])
    private let _errors = LockedValueBox<[RecordedError]>([])
    private let _status = LockedValueBox<SpanStatus?>(nil)
    private let _isRecording = LockedValueBox<Bool>(true)
    private let onEnd: @Sendable (FinishedTestSpan) -> Void

    private func assertIsRecording(
        file: StaticString = #file,
        line: UInt = #line
    ) {
        assert(
            _isRecording.withValue(\.self) == true,
            "Attempted to mutate already ended span.",
            file: file,
            line: line
        )
    }
}

public struct FinishedTestSpan: Sendable {
    public let operationName: String
    public let context: ServiceContext
    public let spanContext: TestSpanContext
    public let startInstant: any TracerInstant
    public let endInstant: any TracerInstant
    public let attributes: SpanAttributes
    public let events: [SpanEvent]
    public let links: [SpanLink]
    public let errors: [TestSpan.RecordedError]
    public let status: SpanStatus?
}
