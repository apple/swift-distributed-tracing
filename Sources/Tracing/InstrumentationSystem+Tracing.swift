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
    /// Returns the ``Tracer`` bootstrapped as part of the `InstrumentationSystem`.
    ///
    /// If the system was bootstrapped with a `MultiplexInstrument` this function attempts to locate the _first_
    /// tracing instrument as passed to the multiplex instrument. If none is found, a ``NoOpTracer`` is returned.
    ///
    /// - Returns: A ``Tracer`` if the system was bootstrapped with one, and ``NoOpTracer`` otherwise.
    public static var tracer: Tracer {
        (self._findInstrument(where: { $0 is Tracer }) as? Tracer) ?? NoOpTracer()
    }
}
