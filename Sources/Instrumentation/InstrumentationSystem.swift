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
/// It is set up just once in a given program to select the desired `Instrument` implementation.
///
/// # Bootstrap multiple Instruments
/// If you need to use more that one cross-cutting tool you can do so by using `MultiplexInstrument`.
///
/// # Access the Instrument
/// There are two ways of getting the bootstrapped instrument.
/// 1. `InstrumentationSystem.instrument`: Returns whatever you passed to `.bootstrap` as an `Instrument`.
/// 2. `InstrumentationSystem.instrument(of: MyInstrument.self)`: Returns the bootstrapped `Instrument` if it's
/// an instance of the given type or the first instance of `MyInstrument` if it's part of a `MultiplexInstrument`.
///
/// ## What getter to use
/// - Default to using `InstrumentationSystem.instrument`
/// - Use `InstrumentationSystem.instrument(of: MyInstrument.self)` only if you need to use specific `MyInstrument` APIs
///
/// Specific instrumentation libraries may also provide their own accessors as extensions, e.g. GreatInstrumentation could provide an
/// `InstrumentationSystem.great` convenience accessor, so prefer using them if available. These accessors should call
/// `.instrument(of: GreatInstrument.self)` under the hood to ensure they work when being used through a `MultiplexInstrument`.
public enum InstrumentationSystem {
    private static let lock = ReadWriteLock()
    private static var _instrument: Instrument = NoOpInstrument()
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
            self._instrument = instrument
            self.isInitialized = true
        }
    }

    // for our testing we want to allow multiple bootstrapping
    internal static func bootstrapInternal(_ instrument: Instrument) {
        self.lock.withWriterLock {
            self._instrument = instrument
        }
    }

    /// Returns the globally configured `Instrument`. Defaults to a no-op `Instrument` if `boostrap` wasn't called before.
    public static var instrument: Instrument {
        self.lock.withReaderLock { self._instrument }
    }
}

extension InstrumentationSystem {
    /// Get an `Instrument` instance of the given type.
    ///
    /// When using `MultiplexInstrument`, this returns the first instance of the given type stored in the `MultiplexInstrument`.
    /// - Parameter instrumentType: The type of `Instrument` you want to retrieve an instance for.
    /// - Returns: An `Instrument` instance of the given type or `nil` if no `Instrument` of that type has been bootstrapped.
    public static func instrument<I>(of instrumentType: I.Type) -> I? {
        self.lock.withReaderLock {
            if let multiplexInstrument = self._instrument as? MultiplexInstrument {
                return multiplexInstrument.firstInstance(of: I.self)
            }
            return self._instrument as? I
        }
    }
}
