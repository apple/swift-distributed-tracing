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

/// A span created by the in-memory tracer that is retained in memory when the trace ends.
///
/// An `InMemorySpan` is created by a ``InMemoryTracer``.
public struct InMemorySpan: Span {

    /// The service context of the span.
    public let context: ServiceContext
    /// The in-memory span context.
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
    ///
    /// When `nil`, this is the top-level span of this trace.
    public var parentSpanID: String? {
        spanContext.parentSpanID
    }

    /// The kind of span
    public let kind: SpanKind
    /// The time instant the span started.
    public let startInstant: any TracerInstant

    private let _operationName: LockedValueBox<String>
    private let _attributes = LockedValueBox<SpanAttributes>([:])
    private let _events = LockedValueBox<[SpanEvent]>([])
    private let _links = LockedValueBox<[SpanLink]>([])
    private let _errors = LockedValueBox<[RecordedError]>([])
    private let _status = LockedValueBox<SpanStatus?>(nil)
    private let _isRecording = LockedValueBox<Bool>(true)
    private let onEnd: @Sendable (FinishedInMemorySpan) -> Void

    /// Creates a new in-memory span
    /// - Parameters:
    ///   - operationName: The operation name this span represents.
    ///   - context: The service context for the span.
    ///   - spanContext: The in-memory span context.
    ///   - kind: The kind of span.
    ///   - startInstant: The time instant the span started.
    ///   - onEnd: A closure invoked when the span completes, providing access to the finished span.
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

    /// A Boolean value that indicates whether the span is still recording mutations.
    ///
    /// The in memory span stops recording mutations performed on the span when it is ended.
    /// In other words, a finished span is not mutable and ignores all subsequent attempts to mutate.
    public var isRecording: Bool {
        _isRecording.withValue { $0 }
    }

    /// The operation name the span represents.
    public var operationName: String {
        get {
            _operationName.withValue { $0 }
        }
        nonmutating set {
            guard isRecording else { return }
            _operationName.withValue { $0 = newValue }
        }
    }

    /// The span attributes.
    public var attributes: SpanAttributes {
        get {
            _attributes.withValue { $0 }
        }
        nonmutating set {
            guard isRecording else { return }
            _attributes.withValue { $0 = newValue }
        }
    }

    /// The events associated with the span.
    public var events: [SpanEvent] {
        _events.withValue { $0 }
    }

    /// Adds an event you provide to the span.
    /// - Parameter event: The event to record.
    public func addEvent(_ event: SpanEvent) {
        guard isRecording else { return }
        _events.withValue { $0.append(event) }
    }

    /// The span links.
    public var links: [SpanLink] {
        _links.withValue { $0 }
    }

    /// Adds a link to the span.
    /// - Parameter link: The link to add.
    public func addLink(_ link: SpanLink) {
        guard isRecording else { return }
        _links.withValue { $0.append(link) }
    }

    /// The errors recorded by the span.
    public var errors: [RecordedError] {
        _errors.withValue { $0 }
    }

    /// Records an error to the span.
    /// - Parameters:
    ///   - error: The error to record.
    ///   - attributes: Span attributes associated with the error.
    ///   - instant: The time instant of the error.
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

    /// The status of the span.
    public var status: SpanStatus? {
        _status.withValue { $0 }
    }

    /// Updates the status of the span to the value you provide.
    /// - Parameter status: The status to set.
    public func setStatus(_ status: SpanStatus) {
        guard isRecording else { return }
        _status.withValue { $0 = status }
    }

    /// Finishes the span.
    /// - Parameter instant: the time instant the span completed.
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

    /// An error recorded to a span.
    public struct RecordedError: Sendable {
        /// The recorded error.
        public let error: Error
        /// The span attributes associated with the error.
        public let attributes: SpanAttributes
        /// The time instant the error occured.
        public let instant: any TracerInstant
    }
}

/// A type that represents a completed span recorded by the in-memory tracer.
public struct FinishedInMemorySpan: Sendable {
    /// The name of the operation the span represents.
    public var operationName: String

    /// The service context of the finished span.
    public var context: ServiceContext
    /// The in-memory span context.
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
    /// The ID of this span.
    public var spanID: String {
        get {
            spanContext.spanID
        }
        set {
            spanContext.spanID = newValue
        }
    }
    /// The ID of the parent span of this span, if there was any.
    ///
    /// When `nil`, this is the top-level span of this trace.
    public var parentSpanID: String? {
        get {
            spanContext.parentSpanID
        }
        set {
            spanContext.parentSpanID = newValue
        }
    }

    /// The kind of span.
    public var kind: SpanKind
    /// The time instant the span started.
    public var startInstant: any TracerInstant
    /// The time instant the span ended.
    public var endInstant: any TracerInstant
    /// The span attributes.
    public var attributes: SpanAttributes
    /// A list of events recorded to the span.
    public var events: [SpanEvent]
    /// A list of links added to the span.
    public var links: [SpanLink]
    /// A list of errors recorded to the span.
    public var errors: [InMemorySpan.RecordedError]
    /// The span status.
    public var status: SpanStatus?
}
