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
                var context = ServiceContext.topLevel
                context[TaskIDKey.self] = name

                lock.lock(context: context)
                lock.unlock(context: context)
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

enum TaskIDKey: ServiceContextKey {
    typealias Value = String
    static let name: String? = "LockedOperationNameKey"
}

// ==== ------------------------------------------------------------------------
// MARK: PrintLn Tracer

/// Only intended to be used in single-threaded testing.
private final class TracedLockPrintlnTracer: LegacyTracer {
    func startAnySpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> any Tracing.Span {
        TracedLockPrintlnSpan(
            operationName: operationName,
            startTime: instant(),
            kind: kind,
            context: context()
        )
    }

    public func forceFlush() {}

    func inject<Carrier, Inject>(
        _ context: ServiceContext,
        into carrier: inout Carrier,
        using injector: Inject
    )
    where
        Inject: Injector,
        Carrier == Inject.Carrier
    {}

    func extract<Carrier, Extract>(
        _ carrier: Carrier,
        into context: inout ServiceContext,
        using extractor: Extract
    )
    where
        Extract: Extractor,
        Carrier == Extract.Carrier
    {}

    final class TracedLockPrintlnSpan: Tracing.Span {
        private let kind: SpanKind

        private var status: SpanStatus?

        private let startTimeMillis: UInt64
        private(set) var endTimeMillis: UInt64?

        var operationName: String
        let context: ServiceContext

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

        init<Instant: TracerInstant>(
            operationName: String,
            startTime: Instant,
            kind: SpanKind,
            context: ServiceContext
        ) {
            self.operationName = operationName
            self.startTimeMillis = startTime.millisecondsSinceEpoch
            self.context = context
            self.kind = kind

            print(
                "  span [\(self.operationName): \(self.context[TaskIDKey.self] ?? "no-name")] @ \(self.startTimeMillis): start"
            )
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

        func recordError<Instant: TracerInstant>(
            _ error: Error,
            attributes: SpanAttributes,
            at instant: @autoclosure () -> Instant
        ) {}

        func end<Instant: TracerInstant>(at instant: @autoclosure () -> Instant) {
            let time = instant()
            self.endTimeMillis = time.millisecondsSinceEpoch
            print("     span [\(self.operationName): \(self.context[TaskIDKey.self] ?? "no-name")] @ \(time): end")
        }
    }
}

extension TracedLockPrintlnTracer: Tracer {
    func startSpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> TracedLockPrintlnSpan {
        TracedLockPrintlnSpan(
            operationName: operationName,
            startTime: instant(),
            kind: kind,
            context: context()
        )
    }
}

extension TracedLockPrintlnTracer: Sendable {}

// only intended for single threaded testing
extension TracedLockPrintlnTracer.TracedLockPrintlnSpan: @unchecked Sendable {}
