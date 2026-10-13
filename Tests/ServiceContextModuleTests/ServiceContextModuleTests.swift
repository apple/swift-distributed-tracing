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

import ServiceContextModule
import Testing

// The full `InstrumentationContext` behavior tests live in `InstrumentationContextTests`. These tests only confirm
// that the `ServiceContext` names, as seen through `ServiceContextModule`, are the `Instrumentation` types.
@Suite("ServiceContextModule Tests")
struct ServiceContextModuleTests {
    private enum TestKey: ServiceContextKey {
        typealias Value = String
    }

    @Test("ServiceContext names are the Instrumentation types")
    func namesAreTheInstrumentationTypes() {
        #expect(ServiceContext.self == InstrumentationContext.self)
        #expect(AnyServiceContextKey.self == AnyInstrumentationContextKey.self)
        #expect((any ServiceContextKey).self == (any InstrumentationContextKey).self)
    }

    @Test("ServiceContext stores and returns a value")
    func storesAndReturnsValue() {
        var context = ServiceContext.topLevel
        #expect(context.isEmpty)

        context[TestKey.self] = "hello"
        #expect(context[TestKey.self] == "hello")
        #expect(context.count == 1)
    }

    @Test("ServiceContext propagates through the task-local current")
    func propagatesThroughTaskLocal() {
        var context = ServiceContext.topLevel
        context[TestKey.self] = "propagated"

        ServiceContext.withValue(context) {
            #expect(ServiceContext.current?[TestKey.self] == "propagated")
        }
    }
}
