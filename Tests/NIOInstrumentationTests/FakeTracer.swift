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
import Foundation
import Instrumentation
import NIOHTTP1

final class FakeTracer: Instrument {
    enum TraceIDKey: BaggageContextKey {
        typealias Value = String
    }

    static let headerName = "fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    func inject<Carrier, Injector>(
        _ context: BaggageContext, into carrier: inout Carrier, using injector: Injector
    )
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier {
        guard let traceID = context[TraceIDKey.self] else { return }
        injector.inject(traceID, forKey: FakeTracer.headerName, into: &carrier)
    }

    func extract<Carrier, Extractor>(
        _ carrier: Carrier, into context: inout BaggageContext, using extractor: Extractor
    )
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier {
        let traceID = extractor.extract(key: FakeTracer.headerName, from: carrier) ?? FakeTracer.defaultTraceID
        context[TraceIDKey.self] = traceID
    }
}
