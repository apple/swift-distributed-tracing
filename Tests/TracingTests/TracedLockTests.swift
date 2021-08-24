//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2021 Apple Inc. and the Swift Distributed Tracing project
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

private final class TracedLockPrintlnTracer: Tracer {
    func startSpan(
        _ operationName: String,
        baggage: Baggage,
        ofKind kind: SpanKind,
        at time: DispatchWallTime
    ) -> Span {
        TracedLockPrintlnSpan(
            operationName: operationName,
            startTime: time,
            kind: kind,
            baggage: baggage
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
        private let operationName: String
        private let kind: SpanKind

        private var status: SpanStatus?

        private let startTime: DispatchWallTime
        private(set) var endTime: DispatchWallTime?

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

        init(
            operationName: String,
            startTime: DispatchWallTime,
            kind: SpanKind,
            baggage: Baggage
        ) {
            self.operationName = operationName
            self.startTime = startTime
            self.baggage = baggage
            self.kind = kind

            print("  span [\(self.operationName): \(self.baggage[TaskIDKey.self] ?? "no-name")] @ \(self.startTime): start")
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

        func recordError(_ error: Error) {}

        func end(at time: DispatchWallTime) {
            self.endTime = time
            print("     span [\(self.operationName): \(self.baggage[TaskIDKey.self] ?? "no-name")] @ \(time): end")
        }
    }
}
