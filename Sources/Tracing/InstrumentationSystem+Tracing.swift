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

@_exported import Instrumentation

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension InstrumentationSystem {
    private static var multiplexTracer: MultiplexTracer? {
        guard let multiplex = self.instrument as? MultiplexInstrument else { return nil }

        let tracers =
            multiplex
            .matchingInstruments(where: { $0 is any LegacyTracer })
            .compactMap { $0 as? any LegacyTracer }

        guard tracers.count > 1 else { return nil }
        return MultiplexTracer(tracers)
    }

    /// Returns the ``Tracer`` bootstrapped as part of the `InstrumentationSystem`.
    ///
    /// If the system was bootstrapped with a `MultiplexInstrument` containing multiple tracing instruments, this
    /// function returns a tracer that forwards span operations to each of them. If none is found, a ``NoOpTracer``
    /// is returned.
    ///
    /// - Returns: A ``Tracer`` if the system was bootstrapped with one, and ``NoOpTracer`` otherwise.
    public static var tracer: any Tracer {
        if let multiplexTracer = self.multiplexTracer {
            return multiplexTracer
        }

        let found: (any Tracer)? =
            (self._findInstrument(where: { $0 is (any Tracer) }) as? (any Tracer))
        return found ?? NoOpTracer()
    }

    /// Returns the ``Tracer`` bootstrapped as part of the `InstrumentationSystem`.
    ///
    /// If the system was bootstrapped with a `MultiplexInstrument` containing multiple tracing instruments, this
    /// function returns a tracer that forwards span operations to each of them. If none is found, a ``NoOpTracer``
    /// is returned.
    ///
    /// - Returns: A ``Tracer`` if the system was bootstrapped with one, and ``NoOpTracer`` otherwise.
    @available(*, deprecated, message: "prefer tracer")
    public static var legacyTracer: any LegacyTracer {
        if let multiplexTracer = self.multiplexTracer {
            return multiplexTracer
        }

        let found: (any LegacyTracer)? =
            (self._findInstrument(where: { $0 is (any LegacyTracer) }) as? (any LegacyTracer))
        return found ?? NoOpTracer()
    }
}
