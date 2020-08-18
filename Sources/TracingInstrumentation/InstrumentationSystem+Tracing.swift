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
import Instrumentation

extension InstrumentationSystem {
    /// Get a `TracingInstrument` instance of the given type.
    ///
    /// When using `MultiplexInstrument`, this returns the first instance of the given type stored in the `MultiplexInstrument`.
    ///
    /// Usually tracing libraries will provide their own convenience getter, e.g. CoolTracing could provide `InstrumentationSystem.coolTracer`;
    /// if available, prefer using those APIs rather than relying on this general function.
    ///
    /// - Parameter instrumentType: The type of `Instrument` you want to retrieve an instance for.
    /// - Returns: An `Instrument` instance of the given type or `nil` if no `Instrument` of that type has been bootstrapped.
    public static func tracingInstrument<T>(of instrumentType: T.Type) -> T? where T: TracingInstrument {
        return self._findInstrument(where: { $0 is T }) as? T
    }

    /// Returns the `TracingInstrument` bootstrapped as part of the `InstrumentationSystem`.
    ///
    /// If the system was bootstrapped with a `MultiplexInstrument` this function attempts to locate the _first_
    /// tracing instrument as passed to the multiplex instrument. If none is found, a `NoOpTracingInstrument` is returned.
    ///
    /// - Returns: A `TracingInstrument` if the system was bootstrapped with one, and `NoOpTracingInstrument` otherwise.
    public static var tracingInstrument: TracingInstrument {
        return (self._findInstrument(where: { $0 is TracingInstrument }) as? TracingInstrument) ?? NoOpTracingInstrument()
    }
}
