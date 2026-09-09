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

@testable import ContextStorage

@Suite("TracingContext Tests")
struct TracingContextTests {
    @Test("Top-level TracingContext is empty")
    func topLevelTracingContextIsEmpty() {
        let context = TracingContext.topLevel

        #expect(context.isEmpty)
        #expect(context.count == 0)
    }

    @Test("Read and write values through subscript")
    func readAndWriteThroughSubscript() throws {
        var context = TracingContext.topLevel
        #expect(context[FirstTestKey.self] == nil)
        #expect(context[SecondTestKey.self] == nil)

        context[FirstTestKey.self] = 42
        context[SecondTestKey.self] = 42.0

        #expect(!context.isEmpty)
        #expect(context.count == 2)
        #expect(context[FirstTestKey.self] == 42)
        #expect(context[SecondTestKey.self] == 42.0)
    }

    @Test("TracingContext forEach iterates over all context items")
    func forEachIteratesOverAllTracingContextItems() {
        var context = TracingContext.topLevel

        context[FirstTestKey.self] = 42
        context[SecondTestKey.self] = 42.0
        context[ThirdTestKey.self] = "test"

        var contextItems = [AnyTracingContextKey: Any]()
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

    @Test("TODO TracingContext does not crash without explicit compiler flag")
    func TODO_doesNotCrashWithoutExplicitCompilerFlag() {
        _ = TracingContext.TODO(#function)
    }

    @Test("TracingContextKey name defaults to type name without override")
    func tracingContextKeyName_withoutOverride() {
        let name = FirstTestKey.name
        #expect(name == "FirstTestKey")
    }

    @Test("TracingContextKey name uses explicit override when provided")
    func tracingContextKeyName_withOverride() {
        let name = ThirdTestKey.name
        #expect(name == "explicit")
    }

    @Test("AnyTracingContextKey name defaults to type name without override")
    func anyTracingContextKeyName_withoutOverride() {
        let anyKey = AnyTracingContextKey(FirstTestKey.self)
        #expect(anyKey.name == "FirstTestKey")
    }

    @Test("AnyTracingContextKey name uses explicit override when provided")
    func anyTracingContextKeyName_withOverride() {
        let anyKey = AnyTracingContextKey(ThirdTestKey.self)
        #expect(anyKey.name == "explicit")
    }

    @Test("TracingContextKey name matches AnyTracingContextKey name")
    func tracingContextKeyName_matchesAnyTracingContextKeyName() {
        #expect(FirstTestKey.name == AnyTracingContextKey(FirstTestKey.self).name)
        #expect(SecondTestKey.name == AnyTracingContextKey(SecondTestKey.self).name)
        #expect(ThirdTestKey.name == AnyTracingContextKey(ThirdTestKey.self).name)
    }

    @Test("Automatic propagation through task-local storage")
    func automaticPropagationThroughTaskLocal() throws {
        guard #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) else {
            #expect(Bool(true), "Task locals are not supported on this platform.")
            return
        }

        #expect(TracingContext.current == nil)

        var context = TracingContext.topLevel
        context[FirstTestKey.self] = 42

        var propagatedTracingContext: TracingContext?
        func exampleFunction() {
            propagatedTracingContext = TracingContext.current
        }

        let c = TracingContext.$current
        c.withValue(context, operation: exampleFunction)

        #expect(propagatedTracingContext?.count == 1)
        #expect(propagatedTracingContext?[FirstTestKey.self] == 42)
    }

    actor SomeActor {
        var value: Int = 0

        func check() async {
            TracingContext.$current.withValue(.topLevel) {
                value = 12  // should produce no warnings
            }
            TracingContext.withValue(.topLevel) {
                value = 12  // should produce no warnings
            }
            await TracingContext.withValue(.topLevel) { () async in
                value = 12  // should produce no warnings
            }
        }
    }

    @available(*, deprecated, message: "Intentionally exercises the deprecated ServiceContext alias.")
    @Test("Deprecated ServiceContext alias is the same type as TracingContext")
    func deprecatedServiceContextAliasStillWorks() {
        var context: ServiceContext = .topLevel
        context[FirstTestKey.self] = 1

        let asTracingContext: TracingContext = context
        #expect(asTracingContext[FirstTestKey.self] == 1)
    }

    @available(*, deprecated, message: "Intentionally exercises the deprecated ServiceContextKey alias.")
    @Test("Deprecated ServiceContextKey alias is the same protocol as TracingContextKey")
    func deprecatedServiceContextKeyAliasStillWorks() {
        enum LegacyKey: ServiceContextKey {
            typealias Value = String
        }

        var context = TracingContext.topLevel
        context[LegacyKey.self] = "legacy"
        #expect(context[LegacyKey.self] == "legacy")
    }

    @available(*, deprecated, message: "Intentionally exercises the deprecated AnyServiceContextKey alias.")
    @Test("Deprecated AnyServiceContextKey alias is the same type as AnyTracingContextKey")
    func deprecatedAnyServiceContextKeyAliasStillWorks() {
        let anyKey: AnyServiceContextKey = AnyTracingContextKey(FirstTestKey.self)
        #expect(anyKey.name == "FirstTestKey")
    }

    private enum FirstTestKey: TracingContextKey {
        typealias Value = Int
    }

    private enum SecondTestKey: TracingContextKey {
        typealias Value = Double
    }

    private enum ThirdTestKey: TracingContextKey {
        typealias Value = String

        static let nameOverride: String? = "explicit"
    }
}
