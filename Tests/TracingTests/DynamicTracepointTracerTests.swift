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

import ServiceContextModule
import Tracing
import XCTest

@testable import Instrumentation

final class DynamicTracepointTracerTests: XCTestCase {
    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }

    func test_adhoc_enableBySourceLoc() {
        let tracer = DynamicTracepointTestTracer()

        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(NoOpTracer())
        }

        let fileID = #fileID
        let fakeLine: UInt = 77  // trick number, see withSpan below.
        let fakeNextLine: UInt = fakeLine + 11
        tracer.enableTracepoint(fileID: fileID, line: fakeLine)
        // Imagine this is set via some "ops command", e.g. `<control> <pid, or ssh or something> trace enable Sample.swift:1234`
        // Effectively enabling tracepoints is similar to tracer bullets, tho bullets are generally "one off",
        // but here we could attach a trace-rate, so e.g.: control `<pid> trace enable Sample:1234 .2` to set 20% sampling rate etc.

        tracer.withAnySpan("dont") { _ in
            // don't capture this span...
        }
        tracer.withAnySpan("yes", line: fakeLine) { _ in
            // do capture this span, and all child spans of it!
            tracer.withAnySpan("yes-inner", line: fakeNextLine) { _ in
                // since the parent of this span was captured, this shall be captured as well
            }
        }
        tracer.withSpan("dont") { _ in
            // don't capture this span...
        }
        tracer.withSpan("yes", line: fakeLine) { _ in
            // do capture this span, and all child spans of it!
            tracer.withSpan("yes-inner", line: fakeNextLine) { _ in
                // since the parent of this span was captured, this shall be captured as well
            }
        }

        XCTAssertEqual(tracer.spans.count, 4)

        for span in tracer.spans {
            XCTAssertEqual(span.context.traceID, "trace-id-fake-\(fileID)-\(fakeLine)")
        }
        XCTAssertEqual(tracer.spans[0].context.spanID, "span-id-fake-\(fileID)-\(fakeLine)")
        XCTAssertEqual(tracer.spans[1].context.spanID, "span-id-fake-\(fileID)-\(fakeNextLine)")
    }

    func test_adhoc_enableByFunction() {
        let tracer = DynamicTracepointTestTracer()

        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(NoOpTracer())
        }

        let fileID = #fileID
        tracer.enableTracepoint(function: "traceMeLogic(fakeLine:)")

        let fakeLine: UInt = 66
        let fakeNextLine: UInt = fakeLine + 11

        self.logic(fakeLine: 55)
        self.traceMeLogic(fakeLine: fakeLine)

        XCTAssertEqual(tracer.spans.count, 2)
        for span in tracer.spans {
            XCTAssertEqual(span.context.traceID, "trace-id-fake-\(fileID)-\(fakeLine)")
        }
        XCTAssertEqual(tracer.spans[0].context.spanID, "span-id-fake-\(fileID)-\(fakeLine)")
        XCTAssertEqual(tracer.spans[1].context.spanID, "span-id-fake-\(fileID)-\(fakeNextLine)")
    }

    func logic(fakeLine: UInt) {
        InstrumentationSystem.tracer.withSpan("\(#function)-dont", line: fakeLine) { _ in
            // inside
        }
    }

    func traceMeLogic(fakeLine: UInt) {
        InstrumentationSystem.tracer.withSpan("\(#function)-yes", line: fakeLine) { _ in
            InstrumentationSystem.tracer.withSpan("\(#function)-yes-inside", line: fakeLine + 11) { _ in
                // inside
            }
        }
    }
}

/// Only intended to be used in single-threaded testing.
final class DynamicTracepointTestTracer: LegacyTracer {
    private(set) var activeTracepoints: Set<TracepointID> = []

    struct TracepointID: Hashable {
        let function: String?
        let fileID: String?
        let line: UInt?

        func matches(tracepoint: TracepointID) -> Bool {
            var match = true
            if let fun = self.function {
                match = match && fun == tracepoint.function
                if !match {  // short-circuit further checks
                    return false
                }
            }
            if let fid = self.fileID {
                match = match && fid == tracepoint.fileID
                if !match {  // short-circuit further checks
                    return false
                }
            }
            if let l = self.line {
                match = match && l == tracepoint.line
                if !match {  // short-circuit further checks
                    return false
                }
            }

            return match
        }
    }

    private(set) var spans: [TracepointSpan] = []
    var onEndSpan: (any Tracing.Span) -> Void = { _ in
    }

    func startAnySpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> any Tracing.Span {
        let tracepoint = TracepointID(function: function, fileID: fileID, line: line)
        guard self.shouldRecord(tracepoint: tracepoint) else {
            return TracepointSpan.notRecording(file: fileID, line: line)
        }

        let span = TracepointSpan(
            operationName: operationName,
            startTime: instant(),
            context: context(),
            kind: kind,
            file: fileID,
            line: line,
            onEnd: self.onEndSpan
        )
        self.spans.append(span)
        return span
    }

    private func shouldRecord(tracepoint: TracepointID) -> Bool {
        #if canImport(_Concurrency)
        if self.isActive(tracepoint: tracepoint) {
            // this tracepoint was specifically activated!
            return true
        }

        // else, perhaps there is already an active span, if so, attach to it
        guard let context = ServiceContext.current else {
            return false
        }

        guard context.traceID != nil else {
            // no span is active, return the context though
            return false
        }

        // there is some active trace already, so we should record as well
        // TODO: this logic may need to become smarter
        return true
        #else
        return false
        #endif
    }

    func isActive(tracepoint: TracepointID) -> Bool {
        for activeTracepoint in self.activeTracepoints {
            if activeTracepoint.matches(tracepoint: tracepoint) {
                return true
            }
        }
        return false
    }

    @discardableResult
    func enableTracepoint(fileID: String, line: UInt? = nil) -> Bool {
        self.activeTracepoints.insert(TracepointID(function: nil, fileID: fileID, line: line)).inserted
    }

    @discardableResult
    func enableTracepoint(function: String, fileID: String? = nil, line: UInt? = nil) -> Bool {
        self.activeTracepoints.insert(TracepointID(function: function, fileID: fileID, line: line)).inserted
    }

    func forceFlush() {}

    func extract<Carrier, Extract>(_ carrier: Carrier, into context: inout ServiceContext, using extractor: Extract)
    where Extract: Extractor, Extract.Carrier == Carrier {
        let traceID = extractor.extract(key: "trace-id", from: carrier) ?? UUID().uuidString
        context.traceID = traceID
    }

    func inject<Carrier, Inject>(_ context: ServiceContext, into carrier: inout Carrier, using injector: Inject)
    where Inject: Injector, Inject.Carrier == Carrier {
        guard let traceID = context.traceID else {
            return
        }
        injector.inject(traceID, forKey: "trace-id", into: &carrier)
    }
}

extension DynamicTracepointTestTracer {
    /// Only intended to be used in single-threaded testing.
    final class TracepointSpan: Tracing.Span {
        private let kind: SpanKind

        private var status: SpanStatus?

        private let startTimestampNanosSinceEpoch: UInt64
        private(set) var endTimestampNanosSinceEpoch: UInt64?

        public var operationName: String
        private(set) var context: ServiceContext
        private(set) var isRecording: Bool = false

        let onEnd: (TracepointSpan) -> Void

        static func notRecording(file fileID: String, line: UInt) -> TracepointSpan {
            let span = TracepointSpan(
                operationName: "",
                startTime: DefaultTracerClock().now,
                context: .topLevel,
                kind: .internal,
                file: fileID,
                line: line,
                onEnd: { _ in () }
            )
            span.isRecording = false
            return span
        }

        init<Instant: TracerInstant>(
            operationName: String,
            startTime: Instant,
            context: ServiceContext,
            kind: SpanKind,
            file fileID: String,
            line: UInt,
            onEnd: @escaping (TracepointSpan) -> Void
        ) {
            self.operationName = operationName
            self.startTimestampNanosSinceEpoch = startTime.nanosecondsSinceEpoch
            self.context = context
            self.onEnd = onEnd
            self.kind = kind

            // inherit or make a new traceID:
            if context.traceID == nil {
                self.context.traceID = "trace-id-fake-\(fileID)-\(line)"
            }

            // always make up a new spanID:
            self.context.spanID = "span-id-fake-\(fileID)-\(line)"
        }

        var attributes: Tracing.SpanAttributes = [:]

        func setStatus(_ status: Tracing.SpanStatus) {
            // nothing
        }

        func addEvent(_ event: Tracing.SpanEvent) {
            // nothing
        }

        func recordError<Instant: TracerInstant>(
            _ error: Error,
            attributes: SpanAttributes,
            at instant: @autoclosure () -> Instant
        ) {
            print("")
        }

        func addLink(_ link: SpanLink) {
            // nothing
        }

        func end<Instant: TracerInstant>(at instant: @autoclosure () -> Instant) {
            self.endTimestampNanosSinceEpoch = instant().nanosecondsSinceEpoch
            self.onEnd(self)
        }
    }
}

extension DynamicTracepointTestTracer: Tracer {
    typealias Span = TracepointSpan

    func startSpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: Tracing.SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> TracepointSpan {
        let tracepoint = TracepointID(function: function, fileID: fileID, line: line)
        guard self.shouldRecord(tracepoint: tracepoint) else {
            return TracepointSpan.notRecording(file: fileID, line: line)
        }

        let span = TracepointSpan(
            operationName: operationName,
            startTime: instant(),
            context: context(),
            kind: kind,
            file: fileID,
            line: line,
            onEnd: self.onEndSpan
        )
        self.spans.append(span)
        return span
    }
}

// only intended for single threaded testing
extension DynamicTracepointTestTracer: @unchecked Sendable {}
// only intended for single threaded testing
extension DynamicTracepointTestTracer.TracepointSpan: @unchecked Sendable {}
