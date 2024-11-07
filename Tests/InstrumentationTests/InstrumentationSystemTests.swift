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
import XCTest

@testable import Instrumentation

extension InstrumentationSystem {
    public static func _instrument<I>(of instrumentType: I.Type) -> I? where I: Instrument {
        self._findInstrument(where: { $0 is I }) as? I
    }
}

final class InstrumentationSystemTests: XCTestCase {
    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }

    func testItProvidesAccessToASingletonInstrument() {
        let tracer = FakeTracer()
        let instrument = FakeInstrument()
        let multiplexInstrument = MultiplexInstrument([tracer, instrument])

        XCTAssertNil(InstrumentationSystem._instrument(of: FakeTracer.self))
        XCTAssertNil(InstrumentationSystem._instrument(of: FakeInstrument.self))

        InstrumentationSystem.bootstrapInternal(multiplexInstrument)
        XCTAssert(InstrumentationSystem.instrument is MultiplexInstrument)
        XCTAssert(InstrumentationSystem._instrument(of: FakeTracer.self) === tracer)
        XCTAssert(InstrumentationSystem._instrument(of: FakeInstrument.self) === instrument)

        InstrumentationSystem.bootstrapInternal(tracer)
        XCTAssertFalse(InstrumentationSystem.instrument is MultiplexInstrument)
        XCTAssert(InstrumentationSystem._instrument(of: FakeTracer.self) === tracer)
        XCTAssertNil(InstrumentationSystem._instrument(of: FakeInstrument.self))
    }
}

private final class FakeTracer: Instrument {
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
}

private final class FakeInstrument: Instrument {
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
}
