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

import Tracing
import XCTest

@testable import Instrumentation

extension InstrumentationSystem {
    public static func _legacyTracer<T>(of tracerType: T.Type) -> T? where T: LegacyTracer {
        self._findInstrument(where: { $0 is T }) as? T
    }

    public static func _tracer<T>(of tracerType: T.Type) -> T? where T: Tracer {
        self._findInstrument(where: { $0 is T }) as? T
    }

    public static func _instrument<I>(of instrumentType: I.Type) -> I? where I: Instrument {
        self._findInstrument(where: { $0 is I }) as? I
    }
}

/// This is the only test relying in the global InstrumentationSystem
final class GlobalTracingInstrumentationSystemTests: XCTestCase {
    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }
    
    func testItProvidesAccessToATracer() {
        let tracer = TestTracer()
        
        XCTAssertNil(InstrumentationSystem._legacyTracer(of: TestTracer.self))
        XCTAssertNil(InstrumentationSystem._tracer(of: TestTracer.self))
        
        InstrumentationSystem.bootstrapInternal(tracer)
        XCTAssertFalse(InstrumentationSystem.instrument is MultiplexInstrument)
        XCTAssert(InstrumentationSystem._instrument(of: TestTracer.self) === tracer)
        XCTAssertNil(InstrumentationSystem._instrument(of: NoOpInstrument.self))
        
        XCTAssert(InstrumentationSystem._legacyTracer(of: TestTracer.self) === tracer)
        XCTAssert(InstrumentationSystem.legacyTracer is TestTracer)
        XCTAssert(InstrumentationSystem._tracer(of: TestTracer.self) === tracer)
        XCTAssert(InstrumentationSystem.tracer is TestTracer)
        
        let multiplexInstrument = MultiplexInstrument([tracer])
        InstrumentationSystem.bootstrapInternal(multiplexInstrument)
        XCTAssert(InstrumentationSystem.instrument is MultiplexInstrument)
        XCTAssert(InstrumentationSystem._instrument(of: TestTracer.self) === tracer)
        
        XCTAssert(InstrumentationSystem._legacyTracer(of: TestTracer.self) === tracer)
        XCTAssert(InstrumentationSystem.legacyTracer is TestTracer)
        XCTAssert(InstrumentationSystem._tracer(of: TestTracer.self) === tracer)
        XCTAssert(InstrumentationSystem.tracer is TestTracer)
    }
}

final class GlobalTracingMethodsTests: XCTestCase {
    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }
    
    func testGlobalTracingMethods() async {
        // Bootstrap with TestTracer to capture spans
        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)

        // Create custom timestamps for testing
        let clock = DefaultTracerClock()
        let customInstant1 = clock.now
        let customInstant2 = clock.now
        let customInstant3 = clock.now

        // Create custom contexts to verify they're preserved
        var customContext1 = ServiceContext.topLevel
        customContext1[TestContextKey.self] = "context1"

        var customContext2 = ServiceContext.topLevel
        customContext2[TestContextKey.self] = "context2"

        // Test 1: startSpan with custom instant
        let span1 = startSpan(
            "startSpan-with-instant",
            at: customInstant1,
            context: customContext1,
            ofKind: .client
        )
        span1.end()

        // Test 2: startSpan without instant (uses default)
        let span2 = startSpan(
            "startSpan-default-instant",
            context: customContext2,
            ofKind: .server
        )
        span2.end()

        // Test 3: startSpan with instant (different parameter order)
        let span3 = startSpan(
            "startSpan-instant-alt",
            context: .topLevel,
            ofKind: .producer,
            at: customInstant2
        )
        span3.end()

        // Test 4: withSpan synchronous with custom instant
        let result1 = withSpan(
            "withSpan-sync-instant",
            at: customInstant3,
            context: customContext1,
            ofKind: .consumer
        ) { span -> String in
            XCTAssertEqual(span.operationName, "withSpan-sync-instant")
            return "sync-result"
        }
        XCTAssertEqual(result1, "sync-result")

        // Test 5: withSpan synchronous without instant
        let result2 = withSpan(
            "withSpan-sync-default",
            context: customContext2,
            ofKind: .internal
        ) { span -> Int in
            XCTAssertEqual(span.operationName, "withSpan-sync-default")
            return 42
        }
        XCTAssertEqual(result2, 42)

        // Test 6: withSpan synchronous with instant (alt parameter order)
        let result3 = withSpan(
            "withSpan-sync-instant-alt",
            context: .topLevel,
            ofKind: .server,
            at: clock.now
        ) { _ in
            "alt-result"
        }
        XCTAssertEqual(result3, "alt-result")

        // Test 7: withSpan async with custom instant and isolation
        let result4 = await withSpan(
            "withSpan-async-instant-isolation",
            at: clock.now,
            context: customContext1,
            ofKind: .client,
            isolation: nil
        ) { span -> String in
            XCTAssertEqual(span.operationName, "withSpan-async-instant-isolation")
            return "async-result"
        }
        XCTAssertEqual(result4, "async-result")

        // Test 8: withSpan async without instant but with isolation
        let result5 = await withSpan(
            "withSpan-async-default-isolation",
            context: customContext2,
            ofKind: .producer,
            isolation: nil
        ) { span -> Bool in
            XCTAssertEqual(span.operationName, "withSpan-async-default-isolation")
            return true
        }
        XCTAssertEqual(result5, true)

        // Test 9: withSpan async with instant, isolation (alt parameter order)
        let result6 = await withSpan(
            "withSpan-async-instant-isolation-alt",
            context: .topLevel,
            ofKind: .consumer,
            at: clock.now,
            isolation: nil
        ) { _ in
            99
        }
        XCTAssertEqual(result6, 99)

        // Verify all spans were recorded with correct properties
        let finishedSpans = tracer.spans
        XCTAssertEqual(finishedSpans.count, 9, "Expected 9 finished spans")

        // Verify span 1: startSpan with custom instant
        let recorded1 = finishedSpans[0]
        XCTAssertEqual(recorded1.operationName, "startSpan-with-instant")
        XCTAssertEqual(recorded1.kind, .client)
        XCTAssertEqual(recorded1.context[TestContextKey.self], "context1")
        XCTAssertEqual(recorded1.startTimestampNanosSinceEpoch, customInstant1.nanosecondsSinceEpoch)

        // Verify span 2: startSpan without instant
        let recorded2 = finishedSpans[1]
        XCTAssertEqual(recorded2.operationName, "startSpan-default-instant")
        XCTAssertEqual(recorded2.kind, .server)
        XCTAssertEqual(recorded2.context[TestContextKey.self], "context2")
        // Note: Can't verify exact instant since it used DefaultTracerClock.now

        // Verify span 3: startSpan with instant (alt)
        let recorded3 = finishedSpans[2]
        XCTAssertEqual(recorded3.operationName, "startSpan-instant-alt")
        XCTAssertEqual(recorded3.kind, .producer)
        XCTAssertEqual(recorded3.startTimestampNanosSinceEpoch, customInstant2.nanosecondsSinceEpoch)

        // Verify span 4: withSpan sync with instant
        let recorded4 = finishedSpans[3]
        XCTAssertEqual(recorded4.operationName, "withSpan-sync-instant")
        XCTAssertEqual(recorded4.kind, .consumer)
        XCTAssertEqual(recorded4.context[TestContextKey.self], "context1")
        XCTAssertEqual(recorded4.startTimestampNanosSinceEpoch, customInstant3.nanosecondsSinceEpoch)

        // Verify span 5: withSpan sync without instant
        let recorded5 = finishedSpans[4]
        XCTAssertEqual(recorded5.operationName, "withSpan-sync-default")
        XCTAssertEqual(recorded5.kind, .internal)
        XCTAssertEqual(recorded5.context[TestContextKey.self], "context2")

        // Verify span 6: withSpan sync with instant (alt)
        let recorded6 = finishedSpans[5]
        XCTAssertEqual(recorded6.operationName, "withSpan-sync-instant-alt")
        XCTAssertEqual(recorded6.kind, .server)

        // Verify span 7: withSpan async with instant and isolation
        let recorded7 = finishedSpans[6]
        XCTAssertEqual(recorded7.operationName, "withSpan-async-instant-isolation")
        XCTAssertEqual(recorded7.kind, .client)
        XCTAssertEqual(recorded7.context[TestContextKey.self], "context1")

        // Verify span 8: withSpan async without instant but with isolation
        let recorded8 = finishedSpans[7]
        XCTAssertEqual(recorded8.operationName, "withSpan-async-default-isolation")
        XCTAssertEqual(recorded8.kind, .producer)
        XCTAssertEqual(recorded8.context[TestContextKey.self], "context2")

        // Verify span 9: withSpan async with instant and isolation (alt)
        let recorded9 = finishedSpans[8]
        XCTAssertEqual(recorded9.operationName, "withSpan-async-instant-isolation-alt")
        XCTAssertEqual(recorded9.kind, .consumer)
    }
}

// Test context key for verification
private enum TestContextKey: ServiceContextKey {
    typealias Value = String
}
