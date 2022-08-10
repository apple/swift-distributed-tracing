//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2022 Apple Inc. and the Swift Distributed Tracing project
// authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import InstrumentationBaggage

/// A pseudo-``Instrument`` that may be used to instrument using multiple other ``Instrument``s across a
/// common `Baggage`.
public struct MultiplexInstrument {
    private var instruments: [Instrument]

    /// Create a ``MultiplexInstrument``.
    ///
    /// - Parameter instruments: An array of ``Instrument``s, each of which will be used to ``Instrument/inject(_:into:using:)`` or ``Instrument/extract(_:into:using:)``
    /// through the same `Baggage`.
    public init(_ instruments: [Instrument]) {
        self.instruments = instruments
    }
}

extension MultiplexInstrument {
    func firstInstrument(where predicate: (Instrument) -> Bool) -> Instrument? {
        self.instruments.first(where: predicate)
    }
}

extension MultiplexInstrument: Instrument {
    public func inject<Carrier, Inject>(_ baggage: Baggage, into carrier: inout Carrier, using injector: Inject)
        where Inject: Injector, Carrier == Inject.Carrier
    {
        self.instruments.forEach { $0.inject(baggage, into: &carrier, using: injector) }
    }

    public func extract<Carrier, Extract>(_ carrier: Carrier, into baggage: inout Baggage, using extractor: Extract)
        where Extract: Extractor, Carrier == Extract.Carrier
    {
        self.instruments.forEach { $0.extract(carrier, into: &baggage, using: extractor) }
    }
}
