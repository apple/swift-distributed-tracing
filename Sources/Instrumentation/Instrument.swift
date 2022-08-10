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

/// Conforming types are used to extract values from a specific `Carrier`.
public protocol Extractor {
    /// The carrier to extract values from.
    associatedtype Carrier

    /// Extract the value for the given key from the `Carrier`.
    ///
    /// - Parameters:
    ///   - key: The key to be extracted.
    ///   - carrier: The `Carrier` to extract from.
    func extract(key: String, from carrier: Carrier) -> String?
}

/// Conforming types are used to inject values into a specific `Carrier`.
public protocol Injector {
    /// The carrier to inject values into.
    associatedtype Carrier

    /// Inject the given value for the given key into the given `Carrier`.
    ///
    /// - Parameters:
    ///   - value: The value to be injected.
    ///   - key: The key for which to inject the value.
    ///   - carrier: The `Carrier` to inject into.
    func inject(_ value: String, forKey key: String, into carrier: inout Carrier)
}

/// Conforming types are usually cross-cutting tools like tracers. They are agnostic of what specific `Carrier` is used
/// to propagate metadata across boundaries, but instead just specify what values to use for which keys.
public protocol Instrument {
    /// Extract values from a `Carrier` by using the given extractor and inject them into the given `Baggage`.
    /// It's quite common for `Instrument`s to come up with new values if they weren't passed along in the given `Carrier`.
    ///
    /// - Parameters:
    ///   - carrier: The `Carrier` that was used to propagate values across boundaries.
    ///   - baggage: The `Baggage` into which these values should be injected.
    ///   - extractor: The ``Extractor`` that extracts values from the given `Carrier`.
    func extract<Carrier, Extract>(_ carrier: Carrier, into baggage: inout Baggage, using extractor: Extract)
        where Extract: Extractor, Extract.Carrier == Carrier

    /// Extract values from a `Baggage` and inject them into the given `Carrier` using the given ``Injector``.
    ///
    /// - Parameters:
    ///   - baggage: The `Baggage` from which relevant information will be extracted.
    ///   - carrier: The `Carrier` into which this information will be injected.
    ///   - injector: The ``Injector`` used to inject extracted `Baggage` into the given `Carrier`.
    func inject<Carrier, Inject>(_ baggage: Baggage, into carrier: inout Carrier, using injector: Inject)
        where Inject: Injector, Inject.Carrier == Carrier
}
