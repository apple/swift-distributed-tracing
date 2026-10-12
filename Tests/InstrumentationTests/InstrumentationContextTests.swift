//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2026 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Testing

@testable import Instrumentation

@Suite("InstrumentationContext Tests")
struct InstrumentationContextTests {
    @Test("Top-level InstrumentationContext is empty")
    func topLevelInstrumentationContextIsEmpty() {
        let context = InstrumentationContext.topLevel

        #expect(context.isEmpty)
        #expect(context.count == 0)
    }

    @Test("Read and write values through subscript")
    func readAndWriteThroughSubscript() throws {
        var context = InstrumentationContext.topLevel
        #expect(context[FirstTestKey.self] == nil)
        #expect(context[SecondTestKey.self] == nil)

        context[FirstTestKey.self] = 42
        context[SecondTestKey.self] = 42.0

        #expect(!context.isEmpty)
        #expect(context.count == 2)
        #expect(context[FirstTestKey.self] == 42)
        #expect(context[SecondTestKey.self] == 42.0)
    }

    @Test("InstrumentationContext forEach iterates over all context items")
    func forEachIteratesOverAllInstrumentationContextItems() {
        var context = InstrumentationContext.topLevel

        context[FirstTestKey.self] = 42
        context[SecondTestKey.self] = 42.0
        context[ThirdTestKey.self] = "test"

        var contextItems = [AnyInstrumentationContextKey: Any]()
        // swift-format-ignore: ReplaceForEachWithForLoop
        context.forEach { key, value in
            contextItems[key] = value
        }
        #expect(contextItems.count == 3)
        #expect(contextItems.contains(where: { $0.key.name == "FirstTestKey" }))
        #expect(contextItems.contains(where: { $0.value as? Int == 42 }))
        #expect(contextItems.contains(where: { $0.key.name == "SecondTestKey" }))
        #expect(contextItems.contains(where: { $0.value as? Double == 42.0 }))
        #expect(contextItems.contains(where: { $0.key.name == "explicit" }))
        #expect(contextItems.contains(where: { $0.value as? String == "test" }))
    }

    @Test("TODO InstrumentationContext does not crash without explicit compiler flag")
    func TODO_doesNotCrashWithoutExplicitCompilerFlag() {
        _ = InstrumentationContext.TODO(#function)
    }

    @Test("InstrumentationContextKey name defaults to type name without override")
    func instrumentationContextKeyName_withoutOverride() {
        let name = FirstTestKey.name
        #expect(name == "FirstTestKey")
    }

    @Test("InstrumentationContextKey name uses explicit override when provided")
    func instrumentationContextKeyName_withOverride() {
        let name = ThirdTestKey.name
        #expect(name == "explicit")
    }

    @Test("AnyInstrumentationContextKey name defaults to type name without override")
    func anyInstrumentationContextKeyName_withoutOverride() {
        let anyKey = AnyInstrumentationContextKey(FirstTestKey.self)
        #expect(anyKey.name == "FirstTestKey")
    }

    @Test("AnyInstrumentationContextKey name uses explicit override when provided")
    func anyInstrumentationContextKeyName_withOverride() {
        let anyKey = AnyInstrumentationContextKey(ThirdTestKey.self)
        #expect(anyKey.name == "explicit")
    }

    @Test("InstrumentationContextKey name matches AnyInstrumentationContextKey name")
    func instrumentationContextKeyName_matchesAnyInstrumentationContextKeyName() {
        #expect(FirstTestKey.name == AnyInstrumentationContextKey(FirstTestKey.self).name)
        #expect(SecondTestKey.name == AnyInstrumentationContextKey(SecondTestKey.self).name)
        #expect(ThirdTestKey.name == AnyInstrumentationContextKey(ThirdTestKey.self).name)
    }

    @Test("Automatic propagation through task-local storage")
    func automaticPropagationThroughTaskLocal() throws {
        guard #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) else {
            #expect(Bool(true), "Task locals are not supported on this platform.")
            return
        }

        #expect(InstrumentationContext.current == nil)

        var context = InstrumentationContext.topLevel
        context[FirstTestKey.self] = 42

        var propagatedInstrumentationContext: InstrumentationContext?
        func exampleFunction() {
            propagatedInstrumentationContext = InstrumentationContext.current
        }

        let c = InstrumentationContext.$current
        c.withValue(context, operation: exampleFunction)

        #expect(propagatedInstrumentationContext?.count == 1)
        #expect(propagatedInstrumentationContext?[FirstTestKey.self] == 42)
    }

    actor SomeActor {
        var value: Int = 0

        func check() async {
            InstrumentationContext.$current.withValue(.topLevel) {
                value = 12  // should produce no warnings
            }
            InstrumentationContext.withValue(.topLevel) {
                value = 12  // should produce no warnings
            }
            await InstrumentationContext.withValue(.topLevel) { () async in
                value = 12  // should produce no warnings
            }
        }
    }

    @available(*, deprecated, message: "Intentionally exercises the deprecated ServiceContext alias.")
    @Test("Deprecated ServiceContext alias is the same type as InstrumentationContext")
    func deprecatedServiceContextAliasStillWorks() {
        var context: ServiceContext = .topLevel
        context[FirstTestKey.self] = 1

        let asInstrumentationContext: InstrumentationContext = context
        #expect(asInstrumentationContext[FirstTestKey.self] == 1)
    }

    @available(*, deprecated, message: "Intentionally exercises the deprecated ServiceContextKey alias.")
    @Test("Deprecated ServiceContextKey alias is the same protocol as InstrumentationContextKey")
    func deprecatedServiceContextKeyAliasStillWorks() {
        enum LegacyKey: ServiceContextKey {
            typealias Value = String
        }

        var context = InstrumentationContext.topLevel
        context[LegacyKey.self] = "legacy"
        #expect(context[LegacyKey.self] == "legacy")
    }

    @available(*, deprecated, message: "Intentionally exercises the deprecated AnyServiceContextKey alias.")
    @Test("Deprecated AnyServiceContextKey alias is the same type as AnyInstrumentationContextKey")
    func deprecatedAnyServiceContextKeyAliasStillWorks() {
        let anyKey: AnyServiceContextKey = AnyInstrumentationContextKey(FirstTestKey.self)
        #expect(anyKey.name == "FirstTestKey")
    }

    private enum FirstTestKey: InstrumentationContextKey {
        typealias Value = Int
    }

    private enum SecondTestKey: InstrumentationContextKey {
        typealias Value = Double
    }

    private enum ThirdTestKey: InstrumentationContextKey {
        typealias Value = String

        static let nameOverride: String? = "explicit"
    }
}
