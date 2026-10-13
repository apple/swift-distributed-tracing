//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// `ServiceContext`, `ServiceContextKey`, and `AnyServiceContextKey` are the former names of
// `InstrumentationContext`, `InstrumentationContextKey`, and `AnyInstrumentationContextKey`. The `Instrumentation`
// module declares the former names as deprecated typealiases. This module declares the same names without the
// deprecation, so `import ServiceContextModule` keeps compiling without a warning. A declaration in this module
// shadows the deprecated declaration that this module re-exports from `Instrumentation`.
//
// `TODOLocation` kept its name. Its typealias makes `ServiceContextModule.TODOLocation` resolve.
@_exported import Instrumentation

/// The former name of `InstrumentationContext`, without a deprecation notice.
public typealias ServiceContext = Instrumentation.InstrumentationContext

/// The former name of `InstrumentationContextKey`, without a deprecation notice.
public typealias ServiceContextKey = Instrumentation.InstrumentationContextKey

/// The former name of `AnyInstrumentationContextKey`, without a deprecation notice.
public typealias AnyServiceContextKey = Instrumentation.AnyInstrumentationContextKey

/// The `TODOLocation` type of the `Instrumentation` module, reachable through this module.
public typealias TODOLocation = Instrumentation.TODOLocation
