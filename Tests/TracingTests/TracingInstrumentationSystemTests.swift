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

final class TracingInstrumentationSystemTests: XCTestCase {
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
