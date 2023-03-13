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

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
public enum Tracer {
    // namespace for short-hand operations on global bootstrapped tracer
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
extension Tracer {
    static func startSpan(
        _ operationName: String,
        baggage: Baggage,
        ofKind kind: SpanKind,
        at time: DispatchWallTime = .now(),
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line
    ) -> any SpanProtocol {
        // Effectively these end up calling the same method, however
        // we try to not use the deprecated methods ourselves anyway
        #if swift(>=5.7.0)
        InstrumentationSystem.tracer.startSpan(
            operationName,
            baggage: baggage,
            ofKind: kind,
            at: time,
            function: function,
            file: fileID,
            line: line
        )
        #else
        InstrumentationSystem.legacyTracer.startAnySpan(
            operationName,
            baggage: baggage,
            ofKind: kind,
            at: time,
            function: function,
            file: fileID,
            line: line
        )
        #endif
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal Baggage
    static func startSpan(
        _ operationName: String,
        ofKind kind: SpanKind,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line
    ) -> any SpanProtocol {
        // Effectively these end up calling the same method, however
        // we try to not use the deprecated methods ourselves anyway
        #if swift(>=5.7.0)
        InstrumentationSystem.tracer.startSpan(
            operationName,
            baggage: .current ?? .topLevel,
            ofKind: kind,
            at: .now(),
            function: function,
            file: fileID,
            line: line
        )
        #else
        InstrumentationSystem.legacyTracer.startAnySpan(
            operationName,
            baggage: .current ?? .topLevel,
            ofKind: kind,
            at: .now(),
            function: function,
            file: fileID,
            line: line
        )
        #endif
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public static func withSpan<T>(
        _ operationName: String,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any SpanProtocol) throws -> T
    ) rethrows -> T {
        #if swift(>=5.7.0)
        try InstrumentationSystem.legacyTracer.withAnySpan(
            operationName,
            ofKind: kind,
            function: function,
            file: fileID,
            line: line
        ) { anySpan in
            try operation(anySpan)
        }
        #else
        try InstrumentationSystem.legacyTracer.withAnySpan(
            operationName,
            ofKind: kind,
            function: function,
            file: fileID,
            line: line
        ) { anySpan in
            try operation(anySpan)
        }
        #endif
    }

    #if swift(>=5.7.0)
    @_unsafeInheritExecutor
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public static func withSpan<T>(
        _ operationName: String,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any SpanProtocol) async throws -> T
    ) async rethrows -> T {
        try await InstrumentationSystem.tracer.withAnySpan(
            operationName,
            ofKind: kind,
            function: function,
            file: fileID,
            line: line
        ) { anySpan in
            try await operation(anySpan)
        }
    }
    #else
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public static func withSpan<T>(
        _ operationName: String,
        ofKind kind: SpanKind = .internal,
        function: String = #function,
        file fileID: String = #fileID,
        line: UInt = #line,
        _ operation: (any SpanProtocol) async throws -> T
    ) async rethrows -> T {
        try await InstrumentationSystem.legacyTracer.withAnySpan(
            operationName,
            ofKind: kind,
            function: function,
            file: fileID,
            line: line
        ) { anySpan in
            try await operation(anySpan)
        }
    }
    #endif
}
