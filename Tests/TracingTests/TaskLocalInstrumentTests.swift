//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2025 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Testing
import Tracing

@testable import Instrumentation

// MARK: - withTracer scoping tests
//
// These extend the `.serialized` `GlobalTracingInstrumentationSystemTests` suite so tests that read or set the
// global `InstrumentationSystem` bootstrap don't race each other. `withTracer(_:_:)` itself only binds a
// task-local instrument — it never mutates the global bootstrap. `InstrumentationSystem.instrument` and the
// free-function `withSpan` / `startSpan` resolve that binding ahead of the bootstrapped instrument, falling
// back to the bootstrap outside the scope.

extension GlobalTracingInstrumentationSystemTests {

    // MARK: - Scope resolution

    @Test("InstrumentationSystem.tracer returns scoped tracer entered via withTracer")
    func tracerReturnsScoped() {
        let testTracer = TestTracer()

        withTracer(testTracer) {
            #expect(InstrumentationSystem.tracer is TestTracer)
        }
    }

    @Test("Scoped instrument is not visible outside the withTracer closure")
    func scopedNotVisibleOutsideClosure() {
        InstrumentationSystem.bootstrapInternal(nil)
        defer { InstrumentationSystem.bootstrapInternal(nil) }

        let testTracer = TestTracer()
        withTracer(testTracer) {
            #expect(InstrumentationSystem.tracer is TestTracer)
        }

        // Outside the scope the task-local is unbound, so resolution falls back to the bootstrap — NoOp here.
        #expect(InstrumentationSystem.tracer is NoOpTracer)
    }

    // MARK: - Composition with the bootstrap

    @Test("withTracer overrides the bootstrapped instrument for its scope, falling back after")
    func overridesBootstrapForScope() {
        let bootstrapped = TestTracer()
        let scoped = TestTracer()
        InstrumentationSystem.bootstrapInternal(bootstrapped)
        defer { InstrumentationSystem.bootstrapInternal(nil) }

        #expect(InstrumentationSystem.tracer as AnyObject === bootstrapped)

        withTracer(scoped) {
            // The task-local override resolves ahead of the bootstrap for the scope.
            #expect(InstrumentationSystem.tracer as AnyObject === scoped)
        }

        // After the scope, resolution falls back to the still-bootstrapped instrument.
        #expect(InstrumentationSystem.tracer as AnyObject === bootstrapped)
    }

    // MARK: - Nesting

    @Test("Nested withTracer replaces — inner tracer is active inside, outer restored after")
    func nestedScopes() {
        let outerTracer = TestTracer()
        let innerTracer = TestTracer()

        withTracer(outerTracer) {
            #expect(InstrumentationSystem.tracer as AnyObject === outerTracer)

            withTracer(innerTracer) {
                // A nested `withTracer` replaces the active instrument for its scope, so the inner
                // tracer is the one discovered here.
                #expect(InstrumentationSystem.tracer as AnyObject === innerTracer)
            }

            #expect(InstrumentationSystem.tracer as AnyObject === outerTracer)
        }
    }

    // MARK: - withSpan / startSpan integration

    @Test("withSpan emits into scoped tracer")
    func withSpanUsesScopedTracer() {
        let testTracer = TestTracer()

        withTracer(testTracer) {
            withSpan("test-operation") { span in
                span.attributes["key"] = "value"
            }
        }

        #expect(testTracer.spans.count == 1)
        #expect(testTracer.spans.first?.operationName == "test-operation")
    }

    @Test("startSpan emits into scoped tracer")
    func startSpanUsesScopedTracer() {
        let testTracer = TestTracer()

        withTracer(testTracer) {
            let span = startSpan("manual-span")
            span.end()
        }

        #expect(testTracer.spans.count == 1)
        #expect(testTracer.spans.first?.operationName == "manual-span")
    }

    // MARK: - Replace semantics

    @Test("Scoping a NoOpTracer replaces an outer scope's Tracer")
    func scopingNoOpTracerReplacesOuterTracer() {
        // Replace semantics: an inner scope binding a `NoOpTracer` replaces the outer `Tracer`, so spans
        // created inside it reach no tracer. This is the supported way to turn tracing off for a scope —
        // unlike scoping an arbitrary non-tracer `Instrument`, which `withTracer(_:_:)`'s parameter type no
        // longer allows.
        let outerTracer = TestTracer()

        withTracer(outerTracer) {
            withTracer(NoOpTracer()) {
                #expect(InstrumentationSystem.tracer is NoOpTracer)
                withSpan("shadowed-op") { _ in }
            }
        }

        #expect(outerTracer.spans.isEmpty)
    }

    @Test("extract/inject resolve through the scoped tracer too, not just span creation")
    func scopedTracerReplacesPropagationToo() {
        let outerWriter = KeyWriterTracer(value: "outer")
        let innerWriter = KeyWriterTracer(value: "inner")

        var context = ServiceContext.topLevel
        let dummy = DummyCarrier()

        // A nested `withTracer` replaces the active instrument, so only the inner tracer's `extract` runs —
        // a `Tracer` is also an `Instrument`, so propagation observes the scope exactly like span creation.
        withTracer(outerWriter) {
            withTracer(innerWriter) {
                InstrumentationSystem.instrument.extract(dummy, into: &context, using: KeyWriterExtractor())
            }
        }

        #expect(context[WrittenValueKey.self] == "inner")
    }

    @Test("inject resolves through the scoped tracer too, not just span creation")
    func scopedTracerReplacesInjectToo() {
        let outerWriter = KeyWriterTracer(value: "outer")
        let innerWriter = KeyWriterTracer(value: "inner")

        var carrier = DummyCarrier()

        withTracer(outerWriter) {
            withTracer(innerWriter) {
                InstrumentationSystem.instrument.inject(
                    ServiceContext.topLevel,
                    into: &carrier,
                    using: KeyWriterInjector()
                )
            }
        }

        #expect(carrier.value == "inner")
    }

    // MARK: - Async

    @Test("withTracer(_:_:) works with async closures")
    func withScopeAsync() async {
        let testTracer = TestTracer()

        await withTracer(testTracer) {
            #expect(InstrumentationSystem.tracer is TestTracer)
        }
    }

    @Test("withSpan uses scoped tracer in async context")
    func withSpanAsyncUsesScopedTracer() async {
        let testTracer = TestTracer()

        await withTracer(testTracer) {
            await withSpan("async-operation") { span in
                span.attributes["async"] = true
            }
        }

        #expect(testTracer.spans.count == 1)
        #expect(testTracer.spans.first?.operationName == "async-operation")
    }

    // MARK: - Sibling scope isolation

    @Test("Sibling withTracer(_:_:) scopes in the same parent task are isolated")
    func siblingScopesAreIsolated() async {
        let tracer1 = TestTracer()
        let tracer2 = TestTracer()

        async let r1: Void = withTracer(tracer1) {
            await Task.yield()
            await withSpan("span-a") { _ in }
        }
        async let r2: Void = withTracer(tracer2) {
            await Task.yield()
            await withSpan("span-b") { _ in }
        }
        _ = await (r1, r2)

        #expect(tracer1.spans.count == 1)
        #expect(tracer1.spans.first?.operationName == "span-a")
        #expect(tracer2.spans.count == 1)
        #expect(tracer2.spans.first?.operationName == "span-b")
    }

    // MARK: - Error propagation and typed throws

    @Test("withTracer(_:_:) propagates errors from sync closures")
    func withScopePropagatesSyncErrors() {
        let tracer = TestTracer()

        do {
            try withTracer(tracer) {
                throw ExampleSpanError()
            }
            Issue.record("Should have thrown")
        } catch {
            #expect(error is ExampleSpanError)
        }
    }

    @Test("withTracer(_:_:) propagates errors from async closures")
    func withScopePropagatesAsyncErrors() async {
        let tracer = TestTracer()

        do {
            try await withTracer(tracer) {
                throw ExampleSpanError()
            }
            Issue.record("Should have thrown")
        } catch {
            #expect(error is ExampleSpanError)
        }
    }

    @Test("withTracer(_:_:) forwards typed throws without hitting the force-cast path")
    func withScopeTypedThrowsRoundTrip() async {
        let tracer = TestTracer()

        // Both the sync and async overloads take a `throws(Failure)` closure. If `withValue` ever forwarded
        // an error whose type was not exactly `Failure`, the internal `throw error as! Failure` would trap.
        func typedThrower() throws(ExampleSpanError) {
            throw ExampleSpanError()
        }

        var caught: ExampleSpanError?
        do {
            try withTracer(tracer) { () throws(ExampleSpanError) in
                try typedThrower()
            }
        } catch {
            caught = error
        }
        #expect(caught != nil)

        var caughtAsync: ExampleSpanError?
        do {
            try await withTracer(tracer) { () async throws(ExampleSpanError) in
                try typedThrower()
            }
        } catch {
            caughtAsync = error
        }
        #expect(caughtAsync != nil)
    }

    // MARK: - Return value forwarding

    @Test("withTracer(_:_:) returns value from sync closure")
    func withScopeReturnsValueSync() {
        let tracer = TestTracer()

        let result = withTracer(tracer) {
            42
        }

        #expect(result == 42)
    }

    @Test("withTracer(_:_:) returns value from async closure")
    func withScopeReturnsValueAsync() async {
        let tracer = TestTracer()

        let result = await withTracer(tracer) {
            "async-result"
        }

        #expect(result == "async-result")
    }

    // MARK: - Task propagation

    @Test("Task.detached does not inherit scoped instrument")
    func detachedTaskDoesNotInherit() async {
        InstrumentationSystem.bootstrapInternal(nil)
        defer { InstrumentationSystem.bootstrapInternal(nil) }

        let testTracer = TestTracer()

        await withTracer(testTracer) {
            #expect(InstrumentationSystem.tracer is TestTracer)

            let resolvedInDetached = await Task.detached {
                InstrumentationSystem.tracer
            }.value

            // The detached task does not inherit the task-local, so it falls back to the bootstrap (NoOp).
            #expect(resolvedInDetached is NoOpTracer)
        }
    }

    @Test("Unstructured Task inherits scoped instrument")
    func unstructuredTaskInheritsInstrument() async {
        let testTracer = TestTracer()

        let resolved = await withTracer(testTracer) {
            await Task {
                InstrumentationSystem.tracer
            }.value
        }

        #expect(resolved is TestTracer)
    }

    @Test("Structured child tasks inherit scoped instrument")
    func structuredChildTasksInheritInstrument() async {
        let testTracer = TestTracer()

        await withTracer(testTracer) {
            for i in 0..<3 {
                await withSpan("task-\(i)") { _ in }
            }
        }

        #expect(testTracer.spans.count == 3)
    }
}

// MARK: - Fixtures for propagation precedence tests

/// `ServiceContext` key written by `KeyWriterTracer` on extract.
private enum WrittenValueKey: ServiceContextKey {
    typealias Value = String
    static var nameOverride: String? { "written-value" }
}

/// Minimal carrier type with a single string slot.
private struct DummyCarrier: Sendable {
    var value: String?
}

/// `Tracer` that writes a fixed string to ``WrittenValueKey`` on `extract` and to the carrier's `value` slot
/// on `inject`, and never produces real spans. Used to verify that `withTracer(_:_:)` scopes propagation, not
/// just span creation.
private final class KeyWriterTracer: Tracer, @unchecked Sendable {
    let value: String

    init(value: String) {
        self.value = value
    }

    func startSpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> NoOpTracer.NoOpSpan {
        NoOpTracer.NoOpSpan(context: context())
    }

    func forceFlush() {}

    func extract<Carrier, Extract>(_ carrier: Carrier, into context: inout ServiceContext, using extractor: Extract)
    where Extract: Extractor, Extract.Carrier == Carrier {
        context[WrittenValueKey.self] = self.value
    }

    func inject<Carrier, Inject>(_ context: ServiceContext, into carrier: inout Carrier, using injector: Inject)
    where Inject: Injector, Inject.Carrier == Carrier {
        injector.inject(self.value, forKey: "written-value", into: &carrier)
    }
}

private struct KeyWriterExtractor: Extractor {
    func extract(key: String, from carrier: DummyCarrier) -> String? {
        carrier.value
    }
}

private struct KeyWriterInjector: Injector {
    func inject(_ value: String, forKey key: String, into carrier: inout DummyCarrier) {
        carrier.value = value
    }
}
