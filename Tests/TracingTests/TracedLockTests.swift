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

@testable import Instrumentation
import InstrumentationBaggage
import Tracing
import XCTest

final class TracedLockTests: XCTestCase {
    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }

    func test_tracesLockedTime() {
        let tracer = TracedLockPrintlnTracer()
        InstrumentationSystem.bootstrapInternal(tracer)

        let lock = TracedLock(name: "my-cool-lock")

        func launchTask(_ name: String) {
            DispatchQueue.global().async {
                var baggage = Baggage.topLevel
                baggage[TaskIDKey.self] = name

                lock.lock(baggage: baggage)
                lock.unlock(baggage: baggage)
            }
        }
        launchTask("one")
        launchTask("two")
        launchTask("three")
        launchTask("four")

        Thread.sleep(forTimeInterval: 1)
    }
}

// ==== ------------------------------------------------------------------------
// MARK: test keys

enum TaskIDKey: BaggageKey {
    typealias Value = String
    static let name: String? = "LockedOperationNameKey"
}

// ==== ------------------------------------------------------------------------
// MARK: PrintLn Tracer

/// Only intended to be used in single-threaded testing.
private final class TracedLockPrintlnTracer: LegacyTracerProtocol {
    func startAnySpan<Clock: TracerClock>(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage,
        ofKind kind: SpanKind,
        clock: Clock,
        function: String,
        file fileID: String,
        line: UInt
    ) -> any Span {
        TracedLockPrintlnSpan(
            operationName: operationName,
            startTime: clock.now,
            kind: kind,
            baggage: baggage()
        )
    }

    public func forceFlush() {}

    func inject<Carrier, Inject>(
        _ baggage: Baggage,
        into carrier: inout Carrier,
        using injector: Inject
    )
        where
        Inject: Injector,
        Carrier == Inject.Carrier {}

    func extract<Carrier, Extract>(
        _ carrier: Carrier,
        into baggage: inout Baggage,
        using extractor: Extract
    )
        where
        Extract: Extractor,
        Carrier == Extract.Carrier {}

    final class TracedLockPrintlnSpan: Span {
        private let kind: SpanKind

        private var status: SpanStatus?

        private let startTimeMillis: UInt64
        private(set) var endTimeMillis: UInt64?

        var operationName: String
        let baggage: Baggage

        private var links = [SpanLink]()

        private var events = [SpanEvent]() {
            didSet {
                self.isRecording = !self.events.isEmpty
            }
        }

        var attributes: SpanAttributes = [:] {
            didSet {
                self.isRecording = !self.attributes.isEmpty
            }
        }

        private(set) var isRecording = false

        init<Instant: TracerInstantProtocol>(
            operationName: String,
            startTime: Instant,
            kind: SpanKind,
            baggage: Baggage
        ) {
            self.operationName = operationName
            self.startTimeMillis = startTime.millisecondsSinceEpoch
            self.baggage = baggage
            self.kind = kind

            print("  span [\(self.operationName): \(self.baggage[TaskIDKey.self] ?? "no-name")] @ \(self.startTimeMillis): start")
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

        func recordError(_ error: Error, attributes: SpanAttributes) {}

        func end<Clock: TracerClock>(clock: Clock) {
            let time = clock.now
            self.endTimeMillis = time.millisecondsSinceEpoch
            print("     span [\(self.operationName): \(self.baggage[TaskIDKey.self] ?? "no-name")] @ \(time): end")
        }
    }
}

#if swift(>=5.7.0)
extension TracedLockPrintlnTracer: TracerProtocol {
    func startSpan<Clock: TracerClock>(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage,
        ofKind kind: SpanKind,
        clock: Clock,
        function: String,
        file fileID: String,
        line: UInt
    ) -> TracedLockPrintlnSpan {
        TracedLockPrintlnSpan(
            operationName: operationName,
            startTime: clock.now,
            kind: kind,
            baggage: baggage()
        )
    }
}
#endif

#if compiler(>=5.6.0)
extension TracedLockPrintlnTracer: Sendable {}
extension TracedLockPrintlnTracer.TracedLockPrintlnSpan: @unchecked Sendable {} // only intended for single threaded testing
#endif
