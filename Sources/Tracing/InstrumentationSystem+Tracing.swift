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

@_exported import Instrumentation

extension InstrumentationSystem {
    /// Returns the ``TracerProtocol`` bootstrapped as part of the `InstrumentationSystem`.
    ///
    /// If the system was bootstrapped with a `MultiplexInstrument` this function attempts to locate the _first_
    /// tracing instrument as passed to the multiplex instrument. If none is found, a ``NoOpTracer`` is returned.
    ///
    /// - Returns: A ``TracerProtocol`` if the system was bootstrapped with one, and ``NoOpTracer`` otherwise.
    #if swift(>=5.6.0) // because we must use `any Existential` to avoid warnings
    public static var tracer: any TracerProtocol {
        (self._findInstrument(where: { $0 is any TracerProtocol }) as? any TracerProtocol) ?? NoOpTracer()
    }
    #else
    public static var tracer: any TracerProtocol {
        (self._findInstrument(where: { $0 is TracerProtocol }) as? TracerProtocol) ?? NoOpTracer()
    }
    #endif
}
