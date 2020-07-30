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

/// An `Instrument` with added functionality for distributed tracing. Is uses the span-based tracing model and is
/// based on the OpenTracing/OpenTelemetry spec.
public protocol TracingInstrument: Instrument {
    /// Start a new `Span` within the given `BaggageContext` at a given timestamp.
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - context: The `BaggageContext` within to start the new `Span`.
    ///   - kind: The `SpanKind` of the new `Span`.
    ///   - timestamp: The `DispatchTime` at which to start the new `Span`. Passing `nil` leaves the timestamp capture to the underlying tracing instrument.
    func startSpan(
        named operationName: String,
        context: BaggageContext,
        ofKind kind: SpanKind,
        at timestamp: Timestamp?
    ) -> Span
}

extension TracingInstrument {
    /// Start a new `Span` within the given `BaggageContext`. This passes `nil` as the timestamp to the tracer, which
    /// usually means it should default to the current timestamp.
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - context: The `BaggageContext` within to start the new `Span`.
    ///   - kind: The `SpanKind` of the `Span` to be created. Defaults to `.internal`.
    ///   - timestamp: The `DispatchTime` at which to start the new `Span`. Defaults to `nil`, meaning the timestamp capture is left up to the underlying tracing instrument.
    public func startSpan(
        named operationName: String,
        context: BaggageContext,
        at timestamp: Timestamp? = nil
    ) -> Span {
        self.startSpan(named: operationName, context: context, ofKind: .internal, at: nil)
    }
}
