//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift Tracing project authors
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
    enum TraceIDKey: Baggage.Key {
        typealias Value = String
    }

    static let headerName = "fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    func inject<Carrier, Injector>(
        _ baggage: Baggage, into carrier: inout Carrier, using injector: Injector
    )
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier
    {
        guard let traceID = baggage[TraceIDKey.self] else { return }
        injector.inject(traceID, forKey: FakeTracer.headerName, into: &carrier)
    }

    func extract<Carrier, Extractor>(
        _ carrier: Carrier, into baggage: inout Baggage, using extractor: Extractor
    )
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier
    {
        let traceID = extractor.extract(key: FakeTracer.headerName, from: carrier) ?? FakeTracer.defaultTraceID
        baggage[TraceIDKey.self] = traceID
    }
}
