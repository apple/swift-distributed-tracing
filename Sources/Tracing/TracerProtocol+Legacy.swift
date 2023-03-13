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

import Dispatch
@_exported import Instrumentation
@_exported import InstrumentationBaggage

// @available(*, deprecated, message: "Use 'TracerProtocol' instead")
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
public protocol LegacyTracerProtocol: InstrumentProtocol {

    // @available(*, deprecated, message: "Use 'TracerProtocol/startSpan' instead")
    func startAnySpan(
        _ operationName: String,
        baggage: Baggage,
        ofKind kind: SpanKind,
        at time: DispatchWallTime,
        function: String,
        file fileID: String,
        line: UInt
    ) -> any SpanProtocol

    /// Export all ended spans to the configured backend that have not yet been exported.
    ///
    /// This function should only be called in cases where it is absolutely necessary,
    /// such as when using some FaaS providers that may suspend the process after an invocation, but before the backend exports the completed spans.
    ///
    /// This function should not block indefinitely, implementations should offer a configurable timeout for flush operations.
    func forceFlush()

}

// ==== ------------------------------------------------------------------
// MARK: Legacy implementations for Swift 5.7

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
extension LegacyTracerProtocol {

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
    public func startAnySpan(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        at time: DispatchWallTime = .now(),
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line
    ) -> any SpanProtocol {
        self.startAnySpan(
            operationName,
            baggage: baggage(),
            ofKind: kind,
            at: time,
            function: function,
            file: fileID,
            line: line)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
    public func withAnySpan<T>(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any SpanProtocol) throws -> T
    ) rethrows -> T {
        let span = self.startAnySpan(operationName, baggage: baggage(), ofKind: kind, at: .now(), function: function, file: fileID, line: line)
        defer { span.end() }
        do {
            return try Baggage.$current.withValue(span.baggage) {
                try operation(span)
            }
        } catch {
            span.recordError(error)
            throw error // rethrow
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func withAnySpan<T>(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage = .current ?? .topLevel,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any SpanProtocol) async throws -> T
    ) async rethrows -> T {
        let span = self.startAnySpan(operationName, baggage: baggage(), ofKind: kind, at: .now(), function: function, file: fileID, line: line)
        defer { span.end() }
        do {
            return try await Baggage.$current.withValue(span.baggage) {
                try await operation(span)
            }
        } catch {
            span.recordError(error)
            throw error // rethrow
        }
    }

}

#if swift(>=5.7.0)
extension TracerProtocol {
    public func startAnySpan(
        _ operationName: String,
        baggage: Baggage,
        ofKind kind: SpanKind,
        at time: DispatchWallTime,
        function: String,
        file fileID: String,
        line: UInt
    ) -> any SpanProtocol {
        self.startSpan(
            operationName,
            baggage: baggage,
            ofKind: kind,
            at: time,
            function: function,
            file: fileID,
            line: line
        )
    }


    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    // @available(*, deprecated, message: "Use 'TracerProtocol/withSpan' instead")
    public func withAnySpan<T>(
        _ operationName: String,
        ofKind kind: SpanKind,
        function: String,
        file fileID: String,
        line: UInt,
        _ operation: (any SpanProtocol) throws -> T
    ) rethrows -> T {
        try self.withSpan(
            operationName,
            ofKind: kind,
            function: function,
            file: fileID,
            line: line) { span in
            try operation(span)
        }
    }

    #if swift(>=5.7.0)
    @_unsafeInheritExecutor
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    // @available(*, deprecated, message: "Use 'TracerProtocol/withSpan' instead")
    public func withAnySpan<T>(
        _ operationName: String,
        ofKind kind: SpanKind,
        function: String,
        file fileID: String,
        line: UInt,
        _ operation: (any SpanProtocol) async throws -> T
    ) async rethrows -> T {
        try await self.withSpan(
            operationName,
            ofKind: kind,
            function: function,
            file: fileID,
            line: line) { span in
            try await operation(span)
        }
    }
    #else
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    // @available(*, deprecated, message: "Use 'TracerProtocol/withSpan' instead")
    public func withAnySpan<T>(
        _ operationName: String,
        ofKind kind: SpanKind,
        function: String,
        file fileID: String,
        line: UInt,
        _ operation: (any SpanProtocol) async throws -> T
    ) async rethrows -> T {
        try await self.withSpan(
            operationName,
            ofKind: kind,
            function: function,
            file: fileID,
            line: line) { span in
            try await operation(span)
        }
    }
    #endif

}
#endif