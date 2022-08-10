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

/// `InstrumentationSystem` is a global facility where the default cross-cutting tool can be configured.
/// It is set up just once in a given program to select the desired ``Instrument`` implementation.
///
/// # Bootstrap multiple Instruments
/// If you need to use more that one cross-cutting tool you can do so by using ``MultiplexInstrument``.
///
/// # Access the Instrument
/// ``instrument``: Returns whatever you passed to ``bootstrap(_:)`` as an ``Instrument``.
public enum InstrumentationSystem {
    private static let lock = ReadWriteLock()
    private static var _instrument: Instrument = NoOpInstrument()
    private static var isInitialized = false

    /// Globally select the desired ``Instrument`` implementation.
    ///
    /// - Parameter instrument: The ``Instrument`` you want to share globally within your system.
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

    /// For testing scenarios one may want to set instruments multiple times, rather than the set-once semantics enforced by ``bootstrap(_:)``.
    ///
    /// - Parameter instrument: the instrument to boostrap the system with, if `nil` the ``NoOpInstrument`` is bootstrapped.
    internal static func bootstrapInternal(_ instrument: Instrument?) {
        self.lock.withWriterLock {
            self._instrument = instrument ?? NoOpInstrument()
        }
    }

    /// Returns the globally configured ``Instrument``.
    ///
    /// Defaults to a no-op ``Instrument`` if ``bootstrap(_:)`` wasn't called before.
    public static var instrument: Instrument {
        self.lock.withReaderLock { self._instrument }
    }
}

extension InstrumentationSystem {
    /// :nodoc: INTERNAL API: Do Not Use
    public static func _findInstrument(where predicate: (Instrument) -> Bool) -> Instrument? {
        self.lock.withReaderLock {
            if let multiplex = self._instrument as? MultiplexInstrument {
                return multiplex.firstInstrument(where: predicate)
            } else if predicate(self._instrument) {
                return self._instrument
            } else {
                return nil
            }
        }
    }
}
