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
// This module keeps `import ServiceContextModule` and the qualified names, such as `ServiceContextModule.ServiceContext`,
// working. It re-exports `Instrumentation`, which declares `ServiceContext`, `ServiceContextKey`, and
// `AnyServiceContextKey` as the former names of `InstrumentationContext`, `InstrumentationContextKey`, and
// `AnyInstrumentationContextKey`.
@_exported import Instrumentation
