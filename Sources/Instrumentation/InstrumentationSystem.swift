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

/// A global facility where the default cross-cutting tool can be configured.
///
/// It is set up just once in a given program to select the desired ``Instrument`` implementation.
///
/// Set up the instrumentation using ``bootstrap(_:)``, and access the globally available instrument using ``instrument``.
/// If you need to use more that one cross-cutting tool you can do so by using ``MultiplexInstrument``.
///
/// To enable scoped overrides (per-test, per-subsystem), use ``withInstrument(_:_:)``, which installs a
/// dedicated task-local instrument as the bootstrap on first use and sets the active instrument on it.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
public enum InstrumentationSystem {
    /// Marked as @unchecked Sendable due to the synchronization being
    /// performed manually using locks.
    private final class Storage: @unchecked Sendable {
        private let lock = ReadWriteLock()
        private var _instrument: Instrument = NoOpInstrument()
        private var _isInitialized = false

        func bootstrap(_ instrument: Instrument) {
            self.lock.withWriterLock {
                precondition(
                    !self._isInitialized,
                    """
                    InstrumentationSystem can only be initialized once per process. Consider using MultiplexInstrument if
                    you need to use multiple instruments.
                    """
                )
                self._instrument = instrument
                self._isInitialized = true
            }
        }

        func bootstrapInternal(_ instrument: Instrument?) {
            self.lock.withWriterLock {
                self._instrument = instrument ?? NoOpInstrument()
            }
        }

        /// Ensure a ``TaskLocalInstrument`` is installed so a scope can be entered, installing one lazily
        /// over the default ``NoOpInstrument`` when nothing has been bootstrapped.
        ///
        /// Uses double-checked locking: the common case — a ``TaskLocalInstrument`` is already installed —
        /// is satisfied under a reader lock, matching the cost of reading ``instrument``. Only the one-time
        /// install (or the crash) takes the writer lock.
        ///
        /// - NoOp bootstrap (nothing installed): install an empty `TaskLocalInstrument()` so the wrapper is
        ///   reachable from discovery and propagation for the duration of any scope.
        /// - ``TaskLocalInstrument`` already installed: nothing to do.
        /// - Any other bootstrapped instrument: crash. The task-local instrument can only be installed when
        ///   the system is otherwise un-bootstrapped. It cannot replace an instrument the application chose to
        ///   bootstrap. `withInstrument` is an application-level facility and must not be called against a
        ///   non-scoping bootstrap (typically from library code).
        @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
        func installTaskLocalInstrumentIfNeeded() {
            // Fast path: already scoping-capable, no write needed.
            if self.lock.withReaderLock({ self._instrument is TaskLocalInstrument }) {
                return
            }
            // Slow path: install over NoOp, or crash. Re-check under the writer lock.
            self.lock.withWriterLock {
                if self._instrument is TaskLocalInstrument {
                    return
                }
                guard self._instrument is NoOpInstrument else {
                    fatalError(
                        """
                        withInstrument(_:_:) requires either an un-bootstrapped InstrumentationSystem or one \
                        already using task-local scoping, but a \(type(of: self._instrument)) was bootstrapped. \
                        It cannot replace a plain bootstrapped instrument. withInstrument(_:_:) is an \
                        application-level facility and must not be called from library code.
                        """
                    )
                }
                self._instrument = TaskLocalInstrument()
            }
        }

        var instrument: Instrument {
            self.lock.withReaderLock { self._instrument }
        }

        func _findInstrument(where predicate: (Instrument) -> Bool) -> Instrument? {
            self.lock.withReaderLock {
                if let container = self._instrument as? _InstrumentContainer {
                    return container.firstInstrument(where: predicate)
                } else if predicate(self._instrument) {
                    return self._instrument
                } else {
                    return nil
                }
            }
        }
    }

    private static let shared = Storage()

    /// Globally select the desired ``Instrument`` implementation.
    ///
    /// - Parameter instrument: The ``Instrument`` you want to share globally within your system.
    ///
    /// > Warning: Do not call this method more than once. This will lead to a crash.
    public static func bootstrap(_ instrument: Instrument) {
        self.shared.bootstrap(instrument)
    }

    /// For testing scenarios one may want to set instruments multiple times, rather than the set-once semantics enforced by ``bootstrap(_:)``.
    ///
    /// - Parameter instrument: the instrument to boostrap the system with, if `nil` the ``NoOpInstrument`` is bootstrapped.
    internal static func bootstrapInternal(_ instrument: Instrument?) {
        self.shared.bootstrapInternal(instrument)
    }

    /// Ensures the system can enter a task-local scope, installing a ``TaskLocalInstrument`` over the
    /// default ``NoOpInstrument`` if nothing has been bootstrapped. Backs ``withInstrument(_:_:)``.
    ///
    /// Crashes if a plain (non-scoping) instrument was bootstrapped. See
    /// ``Storage/installTaskLocalInstrumentIfNeeded()`` for the full semantics.
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    internal static func installTaskLocalInstrumentIfNeeded() {
        self.shared.installTaskLocalInstrumentIfNeeded()
    }

    /// Returns the currently bootstrapped ``Instrument``, or a ``NoOpInstrument`` if none was set.
    ///
    /// When an override has been set via ``withInstrument(_:_:)``, it participates when the returned
    /// instrument's methods are invoked — `inject` / `extract` and discovery (``tracer``,
    /// ``_findInstrument(where:)``) resolve through it.
    ///
    /// > Warning: Do not pass this value to ``withInstrument(_:_:)`` (directly or inside a
    /// > ``MultiplexInstrument``). It is task-local-backed, so re-installing it would resolve a scope that
    /// > contains itself; `withInstrument` rejects it with a crash.
    public static var instrument: Instrument {
        shared.instrument
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
extension InstrumentationSystem {
    /// INTERNAL API: Do Not Use
    ///
    /// Walks the bootstrapped instrument for the first member matching `predicate`. Recurses into
    /// `_InstrumentContainer` members, including ``MultiplexInstrument`` members and the task-local override
    /// installed by ``withInstrument(_:_:)``.
    public static func _findInstrument(where predicate: (Instrument) -> Bool) -> Instrument? {
        self.shared._findInstrument(where: predicate)
    }
}
