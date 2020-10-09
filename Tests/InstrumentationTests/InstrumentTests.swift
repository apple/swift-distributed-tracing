//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import BaggageContext
import Instrumentation
import XCTest

final class InstrumentTests: XCTestCase {
    func testMultiplexInvokesAllInstruments() {
        let instrument = MultiplexInstrument([
            FirstFakeTracer(),
            SecondFakeTracer(),
        ])

        var baggage = Baggage.topLevel
        instrument.extract([String: String](), into: &baggage, using: DictionaryExtractor())

        XCTAssertEqual(baggage[FirstFakeTracer.TraceIDKey.self], FirstFakeTracer.defaultTraceID)
        XCTAssertEqual(baggage[SecondFakeTracer.TraceIDKey.self], SecondFakeTracer.defaultTraceID)

        var subsequentRequestHeaders = ["Accept": "application/json"]
        instrument.inject(baggage, into: &subsequentRequestHeaders, using: DictionaryInjector())

        XCTAssertEqual(subsequentRequestHeaders, [
            "Accept": "application/json",
            FirstFakeTracer.headerName: FirstFakeTracer.defaultTraceID,
            SecondFakeTracer.headerName: SecondFakeTracer.defaultTraceID,
        ])
    }
}

private struct DictionaryInjector: InjectorProtocol {
    func inject(_ value: String, forKey key: String, into dictionary: inout [String: String]) {
        dictionary[key] = value
    }
}

private struct DictionaryExtractor: ExtractorProtocol {
    func extract(key: String, from dictionary: [String: String]) -> String? {
        return dictionary[key]
    }
}

private final class FirstFakeTracer: Instrument {
    enum TraceIDKey: Baggage.Key {
        typealias Value = String

        static let name: String? = "FirstFakeTraceID"
    }

    static let headerName = "first-fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    func inject<Carrier, Injector>(
        _ baggage: Baggage, into carrier: inout Carrier, using injector: Injector
    )
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier {
        guard let traceID = baggage[TraceIDKey.self] else { return }
        injector.inject(traceID, forKey: FirstFakeTracer.headerName, into: &carrier)
    }

    func extract<Carrier, Extractor>(
        _ carrier: Carrier, into baggage: inout Baggage, using extractor: Extractor
    )
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier {
        let traceID = extractor.extract(key: FirstFakeTracer.headerName, from: carrier) ?? FirstFakeTracer.defaultTraceID
        baggage[TraceIDKey.self] = traceID
    }
}

private final class SecondFakeTracer: Instrument {
    enum TraceIDKey: Baggage.Key {
        typealias Value = String

        static let name: String? = "SecondFakeTraceID"
    }

    static let headerName = "second-fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    func inject<Carrier, Injector>(
        _ baggage: Baggage, into carrier: inout Carrier, using injector: Injector
    )
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier {
        guard let traceID = baggage[TraceIDKey.self] else { return }
        injector.inject(traceID, forKey: SecondFakeTracer.headerName, into: &carrier)
    }

    func extract<Carrier, Extractor>(
        _ carrier: Carrier, into baggage: inout Baggage, using extractor: Extractor
    )
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier {
        let traceID = extractor.extract(key: SecondFakeTracer.headerName, from: carrier) ?? SecondFakeTracer.defaultTraceID
        baggage[TraceIDKey.self] = traceID
    }
}
