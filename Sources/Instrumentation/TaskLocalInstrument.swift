//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2025 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ServiceContextModule

/// A dedicated instrument that holds a task-local override, installed as the process-wide bootstrap by
/// ``withInstrument(_:_:)`` the first time it is used (a one-time global bootstrap). Each
/// ``withInstrument(_:_:)`` call sets the override for the duration of a closure, replacing any override an
/// enclosing call set. Discovery and propagation resolve to the override when one is set, otherwise to `inner`
/// (always ``NoOpInstrument`` when installed this way). Useful for parallel-safe testing and scoped overrides.
///
/// This is an implementation detail of ``withInstrument(_:_:)``: applications never construct or bootstrap it
/// directly. An application that bootstraps a plain ``Instrument`` or ``MultiplexInstrument`` — or never calls
/// ``withInstrument(_:_:)`` — pays no task-local read on any hot path. The override read lives inside this
/// type's methods and is only consulted once the type is installed.
///
/// > Note: The task-local override is shared across all ``TaskLocalInstrument`` instances in a process. An
/// > override set via ``with(_:_:)`` is observed by every reachable ``TaskLocalInstrument`` for the duration
/// > of the closure, regardless of which instance is reached during discovery or propagation.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
struct TaskLocalInstrument: Sendable {
    private var inner: any Instrument

    /// Task-local override set by ``withInstrument(_:_:)``, resolved ahead of `inner` for the duration of a
    /// ``with(_:_:)`` scope. Internal storage — callers set it by calling ``withInstrument(_:_:)``.
    @TaskLocal internal static var scoped: (any Instrument)?

    /// Wrap an inner instrument with task-local scoping.
    ///
    /// - Parameter inner: The instrument to wrap. Defaults to ``NoOpInstrument`` so the lazy install
    ///   performed by ``withInstrument(_:_:)`` on an un-bootstrapped system can construct the wrapper without
    ///   picking a base. In that case `inner` is always the no-op.
    init(_ inner: any Instrument = NoOpInstrument()) {
        self.inner = inner
    }

    /// Set `instrument` as the task-local override for the duration of the closure.
    ///
    /// Inside the closure, every ``TaskLocalInstrument`` instance reachable from
    /// ``InstrumentationSystem/instrument`` resolves to `instrument` for both discovery
    /// (``InstrumentationSystem/tracer``, free-function `withSpan` / `startSpan`) and propagation (`inject` /
    /// `extract`). A nested ``with(_:_:)`` fully replaces the override for its scope; the previous override is
    /// restored when the closure returns. To keep several instruments active, pass a ``MultiplexInstrument``.
    ///
    /// - Parameters:
    ///   - instrument: The instrument to set as the override.
    ///   - operation: The closure to run with the override set.
    /// - Returns: The value returned by the closure.
    static func with<Result, Failure: Error>(
        _ instrument: any Instrument,
        _ operation: () throws(Failure) -> Result
    ) throws(Failure) -> Result {
        do {
            return try Self.$scoped.withValue(instrument, operation: operation)
        } catch {
            // FIXME: remove when `TaskLocal.withValue` gains typed-throws support.
            // Safe today: `operation` has typed throws `throws(Failure)`, and `TaskLocal.withValue` is
            // `rethrows` — it does not introduce errors of its own, so every error reaching this catch
            // originated from `operation` and is therefore of type `Failure`.
            throw error as! Failure
        }
    }

    #if compiler(>=6.2)
    /// Async variant of ``with(_:_:)``. See that function for full documentation.
    ///
    /// - Parameters:
    ///   - instrument: The instrument to set as the override.
    ///   - operation: The async closure to run with the override set.
    /// - Returns: The value returned by the closure.
    nonisolated(nonsending) static func with<Result, Failure: Error>(
        _ instrument: any Instrument,
        _ operation: () async throws(Failure) -> Result
    ) async throws(Failure) -> Result {
        do {
            return try await Self.$scoped.withValue(instrument, operation: operation)
        } catch {
            // FIXME: remove when `TaskLocal.withValue` gains typed-throws support.
            // Safe for the same reason as the sync variant above.
            throw error as! Failure
        }
    }
    #else
    /// Async variant of ``with(_:_:)``. See that function for full documentation.
    ///
    /// On compilers without `nonisolated(nonsending)`, an explicit `isolation` parameter keeps `operation`
    /// running on the caller's actor (the `#isolation` default flows through to `TaskLocal.withValue`).
    ///
    /// - Parameters:
    ///   - instrument: The instrument to set as the override.
    ///   - operation: The async closure to run with the override set.
    /// - Returns: The value returned by the closure.
    static func with<Result, Failure: Error>(
        _ instrument: any Instrument,
        isolation: isolated (any Actor)? = #isolation,
        _ operation: () async throws(Failure) -> Result
    ) async throws(Failure) -> Result {
        do {
            return try await Self.$scoped.withValue(instrument, operation: operation)
        } catch {
            // FIXME: remove when `TaskLocal.withValue` gains typed-throws support.
            // Safe for the same reason as the sync variant above.
            throw error as! Failure
        }
    }
    #endif
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension TaskLocalInstrument {
    /// Crashes if `instrument` is, or contains through a ``MultiplexInstrument``, the installed
    /// `TaskLocalInstrument` (i.e. ``InstrumentationSystem/instrument``). Installing it would make the
    /// instrument resolve a scope that contains itself, recursing forever. Called at the start of every
    /// ``withInstrument(_:_:)``.
    static func requireNotSelfReferential(_ instrument: any Instrument) {
        guard !isOrContainsScopingInstrument(instrument) else {
            fatalError(
                """
                withInstrument(_:_:) was passed InstrumentationSystem.instrument — the task-local scoping \
                instrument — directly or inside a MultiplexInstrument. Re-installing it would make the \
                instrument resolve a scope that contains itself and recurse forever. Build the \
                MultiplexInstrument from concrete instruments you hold instead.
                """
            )
        }
    }

    /// Returns `true` if `instrument` is a `TaskLocalInstrument`, or is a ``MultiplexInstrument`` that
    /// contains one at any depth. Unlike `firstInstrument(where:)`, this tests container nodes themselves
    /// rather than only recursing into them.
    static func isOrContainsScopingInstrument(_ instrument: any Instrument) -> Bool {
        if instrument is TaskLocalInstrument {
            return true
        }
        if let multiplex = instrument as? MultiplexInstrument {
            return multiplex.instruments.contains(where: isOrContainsScopingInstrument)
        }
        return false
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension TaskLocalInstrument: _InstrumentContainer {
    /// Resolves the active instrument — the task-local override if one is set, otherwise `inner` — and walks
    /// it, recursing through a nested ``_InstrumentContainer`` (such as a ``MultiplexInstrument``).
    func firstInstrument(where predicate: (Instrument) -> Bool) -> Instrument? {
        let active = Self.scoped ?? self.inner
        if let container = active as? _InstrumentContainer {
            return container.firstInstrument(where: predicate)
        } else if predicate(active) {
            return active
        } else {
            return nil
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension TaskLocalInstrument: Instrument {
    /// Inject through the active instrument — the task-local override if set, otherwise `inner`. A
    /// ``MultiplexInstrument`` override fans out to its members.
    func inject<Carrier, Inject>(_ context: ServiceContext, into carrier: inout Carrier, using injector: Inject)
    where Inject: Injector, Carrier == Inject.Carrier {
        (Self.scoped ?? self.inner).inject(context, into: &carrier, using: injector)
    }

    /// Extract through the active instrument — the task-local override if set, otherwise `inner`. A
    /// ``MultiplexInstrument`` override fans out to its members.
    func extract<Carrier, Extract>(
        _ carrier: Carrier,
        into context: inout ServiceContext,
        using extractor: Extract
    ) where Extract: Extractor, Carrier == Extract.Carrier {
        (Self.scoped ?? self.inner).extract(carrier, into: &context, using: extractor)
    }
}
