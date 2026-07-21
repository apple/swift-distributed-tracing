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
/// To override the active instrument for a scope — a test, a subsystem — without touching the process-wide
/// bootstrap, use ``withInstrument(_:_:)``. It binds a task-local instrument that ``instrument`` and discovery
/// resolve ahead of the bootstrapped one, for the duration of a closure.
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

        var instrument: Instrument {
            self.lock.withReaderLock { self._instrument }
        }

        func firstInstrument(where predicate: (Instrument) -> Bool) -> Instrument? {
            self.lock.withReaderLock {
                InstrumentationSystem.firstInstrument(in: self._instrument, where: predicate)
            }
        }
    }

    private static let shared = Storage()

    /// Task-local instrument override set by ``withInstrument(_:_:)``.
    ///
    /// Resolved ahead of the bootstrapped instrument by ``instrument`` and ``_findInstrument(where:)`` for the
    /// duration of a scope. Internal storage — callers set it by calling ``withInstrument(_:_:)``.
    @TaskLocal
    @usableFromInline
    internal static var _taskLocalInstrument: (any Instrument)?

    /// Runs `operation` with `instrument` bound to the task-local override. Backs ``withInstrument(_:_:)``.
    @usableFromInline
    static func withTaskLocalInstrument<Result>(
        _ instrument: any Instrument,
        operation: () throws -> Result
    ) rethrows -> Result {
        try Self.$_taskLocalInstrument.withValue(instrument, operation: operation)
    }

    #if compiler(>=6.2)
    /// Async variant of ``withTaskLocalInstrument(_:operation:)``.
    @usableFromInline
    nonisolated(nonsending) static func withTaskLocalInstrument<Result>(
        _ instrument: any Instrument,
        operation: nonisolated(nonsending) () async throws -> Result
    ) async rethrows -> Result {
        try await Self.$_taskLocalInstrument.withValue(instrument, operation: operation)
    }
    #else
    /// Async variant of ``withTaskLocalInstrument(_:operation:)``.
    @usableFromInline
    static func withTaskLocalInstrument<Result>(
        _ instrument: any Instrument,
        isolation: isolated (any Actor)? = #isolation,
        operation: () async throws -> Result
    ) async rethrows -> Result {
        try await Self.$_taskLocalInstrument.withValue(instrument, operation: operation)
    }
    #endif

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

    /// The currently active ``Instrument``.
    ///
    /// This is the instrument bound by the innermost enclosing ``withInstrument(_:_:)`` scope, if any,
    /// otherwise the one set with ``bootstrap(_:)`` — and a ``NoOpInstrument`` if neither was set.
    public static var instrument: Instrument {
        Self._taskLocalInstrument ?? self.shared.instrument
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)  // for TaskLocal ServiceContext
extension InstrumentationSystem {
    /// INTERNAL API: Do Not Use
    ///
    /// Finds the first instrument matching `predicate` in the currently active instrument — the
    /// ``withInstrument(_:_:)`` override if one is in scope, otherwise the bootstrapped instrument. If the
    /// active instrument is a ``MultiplexInstrument``, its direct members are checked in order.
    public static func _findInstrument(where predicate: (Instrument) -> Bool) -> Instrument? {
        if let scoped = Self._taskLocalInstrument {
            return Self.firstInstrument(in: scoped, where: predicate)
        }
        return self.shared.firstInstrument(where: predicate)
    }

    /// Returns the first match for `predicate`: `instrument` itself, or — when it is a ``MultiplexInstrument``
    /// — its first direct member satisfying `predicate`. This is not recursive: a ``MultiplexInstrument``
    /// nested inside another is tested as a whole, not descended into.
    fileprivate static func firstInstrument(
        in instrument: Instrument,
        where predicate: (Instrument) -> Bool
    ) -> Instrument? {
        if let multiplex = instrument as? MultiplexInstrument {
            return multiplex.firstInstrument(where: predicate)
        } else if predicate(instrument) {
            return instrument
        } else {
            return nil
        }
    }
}
