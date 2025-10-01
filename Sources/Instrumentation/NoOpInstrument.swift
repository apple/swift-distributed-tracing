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

/// A "no op" implementation of an Instrument.
public struct NoOpInstrument: Instrument {
    public init() {}
    /// Extract values from a service context and inject them into the given carrier using the provided injector.
    ///
    /// - Parameters:
    ///   - context: The `ServiceContext` from which relevant information is extracted.
    ///   - carrier: The `Carrier` into which this information is injected.
    ///   - injector: The ``Injector`` to use to inject extracted `ServiceContext` into the given `Carrier`.
    public func inject<Carrier, Inject>(_ context: ServiceContext, into carrier: inout Carrier, using injector: Inject)
    where Inject: Injector, Carrier == Inject.Carrier {
        // no-op
    }

    /// Extract values from a carrier, using the given extractor, and inject them into the provided service context.
    ///
    /// - Parameters:
    ///   - carrier: The `Carrier` that was used to propagate values across boundaries.
    ///   - context: The `ServiceContext` into which these values should be injected.
    ///   - extractor: The ``Extractor`` that extracts values from the given `Carrier`.
    public func extract<Carrier, Extract>(
        _ carrier: Carrier,
        into context: inout ServiceContext,
        using extractor: Extract
    )
    where Extract: Extractor, Carrier == Extract.Carrier {
        // no-op
    }
}
