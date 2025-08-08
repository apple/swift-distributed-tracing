//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_exported import Instrumentation
@_exported import ServiceContextModule

/// Tracer that ignores all operations, used when no tracing is required.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
public struct NoOpTracer: LegacyTracer {
    public typealias Span = NoOpSpan

    public init() {}

    public func startAnySpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> any Tracing.Span {
        NoOpSpan(context: context())
    }

    public func forceFlush() {}

    public func inject<Carrier, Inject>(_ context: ServiceContext, into carrier: inout Carrier, using injector: Inject)
    where Inject: Injector, Carrier == Inject.Carrier {
        // no-op
    }

    public func extract<Carrier, Extract>(
        _ carrier: Carrier,
        into context: inout ServiceContext,
        using extractor: Extract
    )
    where Extract: Extractor, Carrier == Extract.Carrier {
        // no-op
    }

    public struct NoOpSpan: Tracing.Span {
        public let context: ServiceContext
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

        public init(context: ServiceContext) {
            self.context = context
        }

        public func setStatus(_ status: SpanStatus) {}

        public func addLink(_ link: SpanLink) {}

        public func addEvent(_ event: SpanEvent) {}

        public func recordError<Instant: TracerInstant>(
            _ error: Error,
            attributes: SpanAttributes,
            at instant: @autoclosure () -> Instant
        ) {}

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

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension NoOpTracer: Tracer {
    public func startSpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> NoOpSpan {
        NoOpSpan(context: context())
    }
}
