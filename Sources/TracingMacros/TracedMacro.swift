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

#if compiler(>=6.0)
/// Instrument a function to place the entire body inside a span.
///
/// This macro is equivalent to calling ``/Tracing/withSpan`` in the body, but saves an
/// indentation level and duplication. It introduces a `span` variable into the
/// body of the function which can be used to add attributes to the span.
///
/// Parameters are passed directly to ``/Tracing/withSpan`` where applicable,
/// and omitting the parameters from the macro omit them from the call, falling
/// back to the default.
///
/// - Parameters:
///   - operationName: The name of the operation being traced. Defaults to the name of the function.
///   - context: The `ServiceContext` providing information on where to start the new ``/Tracing/Span``.
///   - kind: The ``/Tracing/SpanKind`` of the new ``/Tracing/Span``.
///   - spanName: The name of the span variable to introduce in the function. Pass `"_"` to omit it.
@attached(body)
public macro Traced(
    _ operationName: String? = nil,
    context: ServiceContext? = nil,
    ofKind kind: SpanKind? = nil,
    span spanName: String = "span"
) = #externalMacro(module: "TracingMacrosImplementation", type: "TracedMacro")
#endif
