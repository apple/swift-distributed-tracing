//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020 Moritz Lang and the Swift Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Baggage
@testable import Instrumentation
import XCTest

final class InstrumentationSystemTests: XCTestCase {
    func testItProvidesAccessToASingletonInstrument() {
        let tracer = FakeTracer()
        let instrument = FakeInstrument()
        let multiplexInstrument = MultiplexInstrument([tracer, instrument])

        XCTAssertNil(InstrumentationSystem.instrument(of: FakeTracer.self))
        XCTAssertNil(InstrumentationSystem.instrument(of: FakeInstrument.self))

        InstrumentationSystem.bootstrapInternal(multiplexInstrument)
        XCTAssert(InstrumentationSystem.instrument is MultiplexInstrument)
        XCTAssert(InstrumentationSystem.instrument(of: FakeTracer.self) === tracer)
        XCTAssert(InstrumentationSystem.instrument(of: FakeInstrument.self) === instrument)

        InstrumentationSystem.bootstrapInternal(tracer)
        XCTAssertFalse(InstrumentationSystem.instrument is MultiplexInstrument)
        XCTAssert(InstrumentationSystem.instrument(of: FakeTracer.self) === tracer)
        XCTAssertNil(InstrumentationSystem.instrument(of: FakeInstrument.self))
    }
}

private final class FakeTracer: Instrument {
    func inject<Carrier, Injector>(_ baggage: BaggageContext, into carrier: inout Carrier, using injector: Injector)
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier {}

    func extract<Carrier, Extractor>(_ carrier: Carrier, into baggage: inout BaggageContext, using extractor: Extractor)
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier {}
}

private final class FakeInstrument: Instrument {
    func inject<Carrier, Injector>(_ baggage: BaggageContext, into carrier: inout Carrier, using injector: Injector)
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier {}

    func extract<Carrier, Extractor>(_ carrier: Carrier, into baggage: inout BaggageContext, using extractor: Extractor)
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier {}
}
