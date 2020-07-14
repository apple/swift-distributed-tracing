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

/// `InstrumentationSystem` is a global facility where the default cross-cutting tool can be configured.
/// It is set up just once in a given program select the desired `Instrument` implementation.
///
/// - Note: If you need to use more that one cross-cutting tool you can do so by using `MultiplexInstrument`.
public enum InstrumentationSystem {
    private static let lock = ReadWriteLock()
    private static var _instrument: Instrument = NoOpInstrument()
    private static var _tracer: TracingInstrument?
    private static var isInitialized = false

    /// Globally select the desired `Instrument` implementation.
    ///
    /// - Parameter instrument: The `Instrument` you want to share globally within your system.
    /// - Warning: Do not call this method more than once. This will lead to a crash.
    public static func bootstrap(_ instrument: Instrument) {
        self.lock.withWriterLock {
            precondition(
                !self.isInitialized, """
                InstrumentationSystem can only be initialized once per process. Consider using MultiplexInstrument if
                you need to use multiple instruments.
                """
            )
            if let tracer = instrument as? TracingInstrument {
                self._tracer = tracer
            }
            self._instrument = instrument

            self.isInitialized = true
        }
    }

    // for our testing we want to allow multiple bootstrapping
    internal static func bootstrapInternal(_ instrument: Instrument) {
        self.lock.withWriterLock {
            if let tracer = instrument as? TracingInstrument {
                self._tracer = tracer
            }
            self._instrument = instrument
        }
    }

    /// Returns the globally configured `Instrument`. Defaults to a no-op `Instrument` if `boostrap` wasn't called before.
    public static var instrument: Instrument {
        self.lock.withReaderLock { self._instrument }
    }

    // FIXME: smarter impl
    public static var tracer: TracingInstrument {
        self.lock.withReaderLock {
            let tracer: TracingInstrument? = self._tracer
            let res: TracingInstrument = tracer ?? NoOpTracingInstrument()
            return res
        }
    }
}
