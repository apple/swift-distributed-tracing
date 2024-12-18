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

/// A pseudo-``Instrument`` that may be used to instrument using multiple other ``Instrument``s across a
/// common `ServiceContext`.
public struct MultiplexInstrument {
    private var instruments: [Instrument]

    /// Create a ``MultiplexInstrument``.
    ///
    /// - Parameter instruments: An array of ``Instrument``s, each of which will be used to ``Instrument/inject(_:into:using:)`` or ``Instrument/extract(_:into:using:)``
    /// through the same `ServiceContext`.
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
    public func inject<Carrier, Inject>(_ context: ServiceContext, into carrier: inout Carrier, using injector: Inject)
    where Inject: Injector, Carrier == Inject.Carrier {
        for instrument in self.instruments { instrument.inject(context, into: &carrier, using: injector) }
    }

    public func extract<Carrier, Extract>(
        _ carrier: Carrier,
        into context: inout ServiceContext,
        using extractor: Extract
    )
    where Extract: Extractor, Carrier == Extract.Carrier {
        for instrument in self.instruments { instrument.extract(carrier, into: &context, using: extractor) }
    }
}
