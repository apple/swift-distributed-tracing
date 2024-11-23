//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2024 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
@_exported import ServiceContextModule
import Tracing

/// A span name for a traced operation, either derived from the function name or explicitly specified.
///
/// When using the ``Traced(_:context:ofKind:span:)`` macro, you can use this to customize the span name.
public struct TracedOperationName: ExpressibleByStringLiteral {
    @usableFromInline
    let value: Name

    @usableFromInline
    enum Name {
        case baseName
        case fullName
        case string(String)
    }

    internal init(value: Name) {
        self.value = value
    }

    /// Use a literal string as an operation name.
    public init(stringLiteral: String) {
        value = .string(stringLiteral)
    }

    /// Use the base name of the attached function.
    ///
    /// For `func preheatOven(temperature: Int)` this is `"preheatOven"`.
    public static let baseName = TracedOperationName(value: .baseName)

    /// Use the full name of the attached function.
    ///
    /// For `func preheatOven(temperature: Int)` this is `"preheatOven(temperature:)"`.
    /// This is provided by the `#function` macro.
    public static let fullName = TracedOperationName(value: .fullName)

    /// Use an explicitly specified operation name.
    public static func string(_ text: String) -> Self {
        .init(value: .string(text))
    }

    /// Helper logic to support the `Traced` macro turning this operation name into a string.
    /// Provided as an inference guide.
    ///
    /// - Parameters:
    ///   - baseName: The value to use for the ``baseName`` case. Must be
    ///     specified explicitly because there's no equivalent of `#function`.
    ///   - fullName: The value to use for the ``fullName`` case.
    @inlinable
    @_documentation(visibility: internal)
    public static func _getOperationName(_ name: Self, baseName: String, fullName: String = #function) -> String {
        switch name.value {
        case .baseName: baseName
        case .fullName: fullName
        case let .string(text): text
        }
    }
}

#if compiler(>=6.0)
/// Instrument a function to place the entire body inside a span.
///
/// This macro is equivalent to calling ``withSpan`` in the body, but saves an
/// indentation level and duplication. It introduces a `span` variable into the
/// body of the function which can be used to add attributes to the span.
///
/// Parameters are passed directly to ``withSpan`` where applicable,
/// and omitting the parameters from the macro omit them from the call, falling
/// back to the default.
///
/// - Parameters:
///   - operationName: The name of the operation being traced.
///   - context: The `ServiceContext` providing information on where to start the new ``Span``.
///   - kind: The ``SpanKind`` of the new ``Span``.
///   - spanName: The name of the span variable to introduce in the function. Pass `"_"` to omit it.
@attached(body)
public macro Traced(
    _ operationName: TracedOperationName = .baseName,
    context: ServiceContext? = nil,
    ofKind kind: SpanKind? = nil,
    span spanName: String = "span"
) = #externalMacro(module: "TracingMacrosImplementation", type: "TracedMacro")
#endif
