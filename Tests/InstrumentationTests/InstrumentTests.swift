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
import Instrumentation
import XCTest

final class InstrumentTests: XCTestCase {
    func testMultiplexInvokesAllInstruments() {
        let instrument = MultiplexInstrument([
            FirstFakeTracer(),
            SecondFakeTracer(),
        ])

        var context = BaggageContext()
        instrument.extract([String: String](), into: &context, using: DictionaryExtractor())

        XCTAssertEqual(context[FirstFakeTracer.TraceIDKey.self], FirstFakeTracer.defaultTraceID)
        XCTAssertEqual(context[SecondFakeTracer.TraceIDKey.self], SecondFakeTracer.defaultTraceID)

        var subsequentRequestHeaders = ["Accept": "application/json"]
        instrument.inject(context, into: &subsequentRequestHeaders, using: DictionaryInjector())

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
    enum TraceIDKey: BaggageContextKey {
        typealias Value = String

        static let name: String? = "FirstFakeTraceID"
    }

    static let headerName = "first-fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    func inject<Carrier, Injector>(
        _ context: BaggageContext, into carrier: inout Carrier, using injector: Injector
    )
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier {
        guard let traceID = context[TraceIDKey.self] else { return }
        injector.inject(traceID, forKey: FirstFakeTracer.headerName, into: &carrier)
    }

    func extract<Carrier, Extractor>(
        _ carrier: Carrier, into context: inout BaggageContext, using extractor: Extractor
    )
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier {
        let traceID = extractor.extract(key: FirstFakeTracer.headerName, from: carrier) ?? FirstFakeTracer.defaultTraceID
        context[TraceIDKey.self] = traceID
    }
}

private final class SecondFakeTracer: Instrument {
    enum TraceIDKey: BaggageContextKey {
        typealias Value = String

        static let name: String? = "SecondFakeTraceID"
    }

    static let headerName = "second-fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    func inject<Carrier, Injector>(
        _ context: BaggageContext, into carrier: inout Carrier, using injector: Injector
    )
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier {
        guard let traceID = context[TraceIDKey.self] else { return }
        injector.inject(traceID, forKey: SecondFakeTracer.headerName, into: &carrier)
    }

    func extract<Carrier, Extractor>(
        _ carrier: Carrier, into context: inout BaggageContext, using extractor: Extractor
    )
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier {
        let traceID = extractor.extract(key: SecondFakeTracer.headerName, from: carrier) ?? SecondFakeTracer.defaultTraceID
        context[TraceIDKey.self] = traceID
    }
}
