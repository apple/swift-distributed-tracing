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
import Tracing

@Suite("Optional metatype of the ServiceContext names")
struct OptionalMetatypeTests {
    @Test("ServiceContext?.self is Optional<ServiceContext>.self")
    func serviceContext() {
        #expect(ObjectIdentifier(ServiceContext?.self) == ObjectIdentifier(Optional<ServiceContext>.self))
        #expect(ObjectIdentifier(ServiceContext?.self) == ObjectIdentifier(Optional<InstrumentationContext>.self))
    }

    @Test("AnyServiceContextKey?.self is Optional<AnyServiceContextKey>.self")
    func anyServiceContextKey() {
        #expect(ObjectIdentifier(AnyServiceContextKey?.self) == ObjectIdentifier(Optional<AnyServiceContextKey>.self))
    }

    @Test("TODOLocation?.self is Optional<TODOLocation>.self")
    func todoLocation() {
        #expect(ObjectIdentifier(TODOLocation?.self) == ObjectIdentifier(Optional<TODOLocation>.self))
    }
}
