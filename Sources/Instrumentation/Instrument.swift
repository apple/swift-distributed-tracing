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

/// A type that allows extracting values from an associated carrier.
///
/// The assocaited type, `Carrier`, is a service request such as an HTTP request,
/// that has string values that can be extracted to provide information for a tracing span.
///
/// Typically the library adopting instrumentation provides an implementation of this type, since it is aware of its carrier type.
/// That type can be combined with instrumentation or tracing implementations, which are not aware of the concrete carrier,
/// and only provide an ``Instrument`` (or `Tracer`) which makes use of injector/extractor to operate on carrier values.
public protocol Extractor: Sendable {
    /// The carrier to extract values from.
    associatedtype Carrier: Sendable

    /// Extract the value for the given key from the `Carrier`.
    ///
    /// - Parameters:
    ///   - key: The key to extract.
    ///   - carrier: The `Carrier` to extract from.
    func extract(key: String, from carrier: Carrier) -> String?
}

/// A type that allows you to inject values to an associated carrier.
///
/// The associated type, `Carrier`, is often a client or outgoing request into which values are inserted for tracing spans.
///
/// Typically the library adopting instrumentation provides an implementation of this type, since it is aware of its carrier type.
/// That type can be combined with instrumentation or tracing implementations, which are not aware of the concrete carrier,
/// and only provide an ``Instrument`` (or `Tracer`) which makes use of injector/extractor to operate on carrier values.
public protocol Injector: Sendable {
    /// The carrier to inject values into.
    associatedtype Carrier: Sendable

    /// Inject the given value for the given key into the given `Carrier`.
    ///
    /// - Parameters:
    ///   - value: The value to be injected.
    ///   - key: The key for which to inject the value.
    ///   - carrier: The `Carrier` to inject into.
    func inject(_ value: String, forKey key: String, into carrier: inout Carrier)
}

/// A type that represents a cross-cutting tool, such as a tracer, that provides the a means to extract and inject service contexts into an associated carrier.
///
/// The types are agnostic of the specific `Carrier` used to propagate metadata across API boundaries.
/// Instead they specify the values to use for which keys.
///
/// Typically this type is implemented by an instrumentation, or tracing, library, while the injector/extractor types are implemented by a concrete library adopting the instrumentation library.
public protocol Instrument: Sendable {
    /// Extract values from a carrier, using the given extractor, and inject them into the provided service context.
    ///
    /// It's quite common for `Instrument`s to come up with new values if they weren't passed along in the given `Carrier`.
    ///
    /// - Parameters:
    ///   - carrier: The `Carrier` that was used to propagate values across boundaries.
    ///   - context: The `ServiceContext` into which these values should be injected.
    ///   - extractor: The ``Extractor`` that extracts values from the given `Carrier`.
    func extract<Carrier, Extract>(_ carrier: Carrier, into context: inout ServiceContext, using extractor: Extract)
    where Extract: Extractor, Extract.Carrier == Carrier

    /// Extract values from a service context and inject them into the given carrier using the provided injector.
    ///
    /// - Parameters:
    ///   - context: The `ServiceContext` from which relevant information is extracted.
    ///   - carrier: The `Carrier` into which this information is injected.
    ///   - injector: The ``Injector`` to use to inject extracted `ServiceContext` into the given `Carrier`.
    func inject<Carrier, Inject>(_ context: ServiceContext, into carrier: inout Carrier, using injector: Inject)
    where Inject: Injector, Inject.Carrier == Carrier
}
