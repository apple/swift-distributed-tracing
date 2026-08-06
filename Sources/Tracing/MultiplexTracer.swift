//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License 2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Instrumentation

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
package final class MultiplexSpan: Span, @unchecked Sendable {
    private let spans: [any Span]

    package init(_ spans: [any Span]) {
        precondition(!spans.isEmpty, "A multiplex span must contain at least one span")
        self.spans = spans
    }

    package var context: ServiceContext {
        self.spans[0].context
    }

    package var operationName: String {
        get { self.spans[0].operationName }
        set {
            for span in self.spans {
                span.operationName = newValue
            }
        }
    }

    package func setStatus(_ status: SpanStatus) {
        for span in self.spans {
            span.setStatus(status)
        }
    }

    package func addEvent(_ event: SpanEvent) {
        for span in self.spans {
            span.addEvent(event)
        }
    }

    package func recordError<Instant: TracerInstant>(
        _ error: Error,
        attributes: SpanAttributes,
        at instant: @autoclosure () -> Instant
    ) {
        let resolvedInstant = instant()
        for span in self.spans {
            span.recordError(error, attributes: attributes, at: resolvedInstant)
        }
    }

    package var attributes: SpanAttributes {
        get { self.spans[0].attributes }
        set {
            for span in self.spans {
                span.attributes = newValue
            }
        }
    }

    package var isRecording: Bool {
        self.spans.contains(where: { $0.isRecording })
    }

    package func addLink(_ link: SpanLink) {
        for span in self.spans {
            span.addLink(link)
        }
    }

    package func end<Instant: TracerInstant>(at instant: @autoclosure () -> Instant) {
        let resolvedInstant = instant()
        for span in self.spans {
            span.end(at: resolvedInstant)
        }
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
package final class MultiplexTracer: Tracer {
    package typealias Span = MultiplexSpan

    private let tracers: [any LegacyTracer]

    package init(_ tracers: [any LegacyTracer]) {
        precondition(tracers.count > 1, "A multiplex tracer must contain multiple tracers")
        self.tracers = tracers
    }

    package func inject<Carrier, Inject>(_ context: ServiceContext, into carrier: inout Carrier, using injector: Inject)
    where Inject: Injector, Carrier == Inject.Carrier {
        for tracer in self.tracers {
            tracer.inject(context, into: &carrier, using: injector)
        }
    }

    package func extract<Carrier, Extract>(
        _ carrier: Carrier,
        into context: inout ServiceContext,
        using extractor: Extract
    )
    where Extract: Extractor, Carrier == Extract.Carrier {
        for tracer in self.tracers {
            tracer.extract(carrier, into: &context, using: extractor)
        }
    }

    package func startAnySpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> any Tracing.Span {
        let resolvedContext = context()
        let resolvedInstant = instant()
        let spans = self.tracers.map { tracer in
            tracer.startAnySpan(
                operationName,
                context: resolvedContext,
                ofKind: kind,
                at: resolvedInstant,
                function: function,
                file: fileID,
                line: line
            )
        }
        return MultiplexSpan(spans)
    }

    package func startSpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> MultiplexSpan {
        let resolvedContext = context()
        let resolvedInstant = instant()
        let spans = self.tracers.map { tracer in
            tracer.startAnySpan(
                operationName,
                context: resolvedContext,
                ofKind: kind,
                at: resolvedInstant,
                function: function,
                file: fileID,
                line: line
            )
        }
        return MultiplexSpan(spans)
    }

    package func activeSpan(identifiedBy context: ServiceContext) -> MultiplexSpan? {
        let spans = self.tracers.compactMap { tracer -> (any Tracing.Span)? in
            guard let tracer = tracer as? any Tracer else { return nil }
            return tracer.activeSpan(identifiedBy: context)
        }
        guard !spans.isEmpty else { return nil }
        return MultiplexSpan(spans)
    }

    package func forceFlush() {
        for tracer in self.tracers {
            tracer.forceFlush()
        }
    }
}
