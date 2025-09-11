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

/// A ``Span`` created by the ``InMemoryTracer`` that will be retained in memory when ended.
/// See ``InMemoryTracer/
public struct InMemorySpan: Span {

    public let context: ServiceContext
    public var spanContext: InMemorySpanContext {
        context.inMemorySpanContext!
    }

    /// The ID of the overall trace this span belongs to.
    public var traceID: String {
        spanContext.spanID
    }
    /// The ID of this concrete span.
    public var spanID: String {
        spanContext.spanID
    }
    /// The ID of the parent span of this span, if there was any.
    /// When this is `nil` it means this is the top-level span of this trace.
    public var parentSpanID: String? {
        spanContext.parentSpanID
    }

    public let kind: SpanKind
    public let startInstant: any TracerInstant

    private let _operationName: LockedValueBox<String>
    private let _attributes = LockedValueBox<SpanAttributes>([:])
    private let _events = LockedValueBox<[SpanEvent]>([])
    private let _links = LockedValueBox<[SpanLink]>([])
    private let _errors = LockedValueBox<[RecordedError]>([])
    private let _status = LockedValueBox<SpanStatus?>(nil)
    private let _isRecording = LockedValueBox<Bool>(true)
    private let onEnd: @Sendable (FinishedInMemorySpan) -> Void

    public init(
        operationName: String,
        context: ServiceContext,
        spanContext: InMemorySpanContext,
        kind: SpanKind,
        startInstant: any TracerInstant,
        onEnd: @escaping @Sendable (FinishedInMemorySpan) -> Void
    ) {
        self._operationName = LockedValueBox(operationName)
        var context = context
        context.inMemorySpanContext = spanContext
        self.context = context
        self.kind = kind
        self.startInstant = startInstant
        self.onEnd = onEnd
    }

    /// The in memory span stops recording (storing mutations performed on the span) when it is ended.
    /// In other words, a finished span no longer is mutable and will ignore all subsequent attempts to mutate.
    public var isRecording: Bool {
        _isRecording.withValue { $0 }
    }

    public var operationName: String {
        get {
            _operationName.withValue { $0 }
        }
        nonmutating set {
            guard isRecording else { return }
            _operationName.withValue { $0 = newValue }
        }
    }

    public var attributes: SpanAttributes {
        get {
            _attributes.withValue { $0 }
        }
        nonmutating set {
            guard isRecording else { return }
            _attributes.withValue { $0 = newValue }
        }
    }

    public var events: [SpanEvent] {
        _events.withValue { $0 }
    }

    public func addEvent(_ event: SpanEvent) {
        guard isRecording else { return }
        _events.withValue { $0.append(event) }
    }

    public var links: [SpanLink] {
        _links.withValue { $0 }
    }

    public func addLink(_ link: SpanLink) {
        guard isRecording else { return }
        _links.withValue { $0.append(link) }
    }

    public var errors: [RecordedError] {
        _errors.withValue { $0 }
    }

    public func recordError(
        _ error: any Error,
        attributes: SpanAttributes,
        at instant: @autoclosure () -> some TracerInstant
    ) {
        guard isRecording else { return }
        _errors.withValue {
            $0.append(RecordedError(error: error, attributes: attributes, instant: instant()))
        }
    }

    public var status: SpanStatus? {
        _status.withValue { $0 }
    }

    public func setStatus(_ status: SpanStatus) {
        guard isRecording else { return }
        _status.withValue { $0 = status }
    }

    public func end(at instant: @autoclosure () -> some TracerInstant) {
        let shouldRecord = _isRecording.withValue {
            let value = $0
            $0 = false  // from here on after, stop recording
            return value
        }
        guard shouldRecord else { return }

        let finishedSpan = FinishedInMemorySpan(
            operationName: operationName,
            context: context,
            kind: kind,
            startInstant: startInstant,
            endInstant: instant(),
            attributes: attributes,
            events: events,
            links: links,
            errors: errors,
            status: status
        )
        onEnd(finishedSpan)
    }

    public struct RecordedError: Sendable {
        public let error: Error
        public let attributes: SpanAttributes
        public let instant: any TracerInstant
    }
}

/// Represents a finished span (a ``Span`` that `end()` was called on)
/// that was recorded by the ``InMemoryTracer``.
public struct FinishedInMemorySpan: Sendable {
    public var operationName: String

    public var context: ServiceContext
    public var spanContext: InMemorySpanContext {
        get {
            context.inMemorySpanContext!
        }
        set {
            context.inMemorySpanContext = newValue
        }
    }

    /// The ID of the overall trace this span belongs to.
    public var traceID: String {
        get {
            spanContext.spanID
        }
        set {
            spanContext.spanID = newValue
        }
    }
    /// The ID of this concrete span.
    public var spanID: String {
        get {
            spanContext.spanID
        }
        set {
            spanContext.spanID = newValue
        }
    }
    /// The ID of the parent span of this span, if there was any.
    /// When this is `nil` it means this is the top-level span of this trace.
    public var parentSpanID: String? {
        get {
            spanContext.parentSpanID
        }
        set {
            spanContext.parentSpanID = newValue
        }
    }

    public var kind: SpanKind
    public var startInstant: any TracerInstant
    public var endInstant: any TracerInstant
    public var attributes: SpanAttributes
    public var events: [SpanEvent]
    public var links: [SpanLink]
    public var errors: [InMemorySpan.RecordedError]
    public var status: SpanStatus?
}
