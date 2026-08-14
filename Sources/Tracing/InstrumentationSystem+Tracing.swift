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
    /// Returns the active ``Tracer``: the one bound by the innermost enclosing `withTracer(_:_:)` scope if
    /// any, otherwise the one bootstrapped as part of the `InstrumentationSystem`.
    ///
    /// If the active instrument is a `MultiplexInstrument` this function attempts to locate the _first_
    /// tracing instrument passed to it. If none is found, a ``NoOpTracer`` is returned.
    ///
    /// Checks the task-local first, and only reads the bootstrapped instrument if it is not set. A resolution
    /// inside `withTracer(_:_:)` returns from the task-local directly and never touches the bootstrapped
    /// storage. An application that only calls ``bootstrap(_:)`` pays for that extra check on every
    /// lookup.
    ///
    /// - Returns: A ``Tracer`` if one is active, and ``NoOpTracer`` otherwise.
    public static var tracer: any Tracer {
        let found: (any Tracer)? =
            (self._findInstrument(where: { $0 is (any Tracer) }) as? (any Tracer))
        return found ?? NoOpTracer()
    }

    /// Returns the active ``Tracer``: the one bound by the innermost enclosing `withTracer(_:_:)` scope if
    /// any, otherwise the one bootstrapped as part of the `InstrumentationSystem`.
    ///
    /// If the active instrument is a `MultiplexInstrument` this function attempts to locate the _first_
    /// tracing instrument passed to it. If none is found, a ``NoOpTracer`` is returned.
    ///
    /// - Returns: A ``Tracer`` if one is active, and ``NoOpTracer`` otherwise.
    @available(*, deprecated, message: "prefer tracer")
    public static var legacyTracer: any LegacyTracer {
        let found: (any LegacyTracer)? =
            (self._findInstrument(where: { $0 is (any LegacyTracer) }) as? (any LegacyTracer))
        return found ?? NoOpTracer()
    }
}
