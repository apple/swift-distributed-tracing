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

// MARK: - withInstrument scoping tests
//
// These extend the `.serialized` `GlobalTracingInstrumentationSystemTests` suite so that mutating the global
// `InstrumentationSystem` doesn't race other tests. `withInstrument(_:_:)` installs the `TaskLocalInstrument`
// wrapper lazily on first use (over the default `NoOpInstrument`) and sets the scoped override on it, which is
// then reachable from `InstrumentationSystem.instrument` and the free-function `withSpan` / `startSpan`.

extension GlobalTracingInstrumentationSystemTests {

    // MARK: - Scope resolution

    @Test("InstrumentationSystem.tracer returns scoped tracer entered via withInstrument")
    func tracerReturnsScoped() {
        let testTracer = TestTracer()

        withInstrument(testTracer) {
            #expect(InstrumentationSystem.tracer is TestTracer)
        }
    }

    @Test("Scoped instrument is not visible outside the withInstrument closure")
    func scopedNotVisibleOutsideClosure() {
        let testTracer = TestTracer()

        withInstrument(testTracer) {
            #expect(InstrumentationSystem.tracer is TestTracer)
        }

        // Outside the scope, no scoped tracer is layered. With baseline `TaskLocalInstrument()` (which
        // wraps `NoOpInstrument`) and no other tracer reachable, discovery returns NoOp.
        #expect(InstrumentationSystem.tracer is NoOpTracer)
    }

    // MARK: - Nesting

    @Test("Nested withInstrument replaces — inner tracer is active inside, outer restored after")
    func nestedScopes() {
        let outerTracer = TestTracer()
        let innerTracer = TestTracer()

        withInstrument(outerTracer) {
            #expect(InstrumentationSystem.tracer as AnyObject === outerTracer)

            withInstrument(innerTracer) {
                // A nested `withInstrument` replaces the active instrument for its scope, so the inner
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

        withInstrument(testTracer) {
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

        withInstrument(testTracer) {
            let span = startSpan("manual-span")
            span.end()
        }

        #expect(testTracer.spans.count == 1)
        #expect(testTracer.spans.first?.operationName == "manual-span")
    }

    // MARK: - MultiplexInstrument resolution

    @Test("withSpan finds a Tracer inside a MultiplexInstrument bound via withInstrument(_:_:)")
    func withSpanResolvesTracerFromScopedMultiplex() {
        let tracer = TestTracer()
        let multiplex = MultiplexInstrument([NoOpInstrument(), tracer])

        withInstrument(multiplex) {
            withSpan("multiplex-op") { _ in }
        }

        #expect(tracer.spans.count == 1)
        #expect(tracer.spans.first?.operationName == "multiplex-op")
    }

    @Test("withSpan finds a LegacyTracer-only conformer nested in a scoped MultiplexInstrument")
    func withSpanFindsLegacyOnlyNestedInScopedMultiplex() {
        let legacyOnly = LegacyOnlyTestTracer()
        let scopedMultiplex = MultiplexInstrument([legacyOnly])

        withInstrument(scopedMultiplex) {
            withSpan("scoped-legacy-op") { _ in }
        }

        #expect(legacyOnly.startedOperationNames == ["scoped-legacy-op"])
    }

    // MARK: - Replace semantics

    @Test("A nested withInstrument replaces the outer instrument for its scope")
    func nestedScopeReplacesOuter() {
        let outerWriter = KeyWriterInstrument(value: "outer")
        let innerWriter = KeyWriterInstrument(value: "inner")

        var context = ServiceContext.topLevel
        let dummy = DummyCarrier()

        // A nested `withInstrument` replaces the active instrument, so only the inner writer runs.
        withInstrument(outerWriter) {
            withInstrument(innerWriter) {
                InstrumentationSystem.instrument.extract(dummy, into: &context, using: KeyWriterExtractor())
            }
        }

        #expect(context[WrittenValueKey.self] == "inner")
    }

    @Test("Scoping a non-Tracer shadows an outer scope's Tracer")
    func scopingNonTracerShadowsOuterTracer() {
        // Replace semantics: an inner scope binding a non-Tracer shadows the outer Tracer, so spans created
        // inside it reach no tracer. Pass a `MultiplexInstrument` if you want to keep a tracer active.
        let outerTracer = TestTracer()

        withInstrument(outerTracer) {
            withInstrument(NoOpInstrument()) {
                #expect(InstrumentationSystem.tracer is NoOpTracer)
                withSpan("shadowed-op") { _ in }
            }
        }

        #expect(outerTracer.spans.isEmpty)
    }

    // MARK: - MultiplexInstrument fan-out

    @Test("A MultiplexInstrument override fans out extract to all members, last member wins overlaps")
    func multiplexFansOutExtract() {
        let writerA = KeyWriterInstrument(value: "a")
        let writerB = KeyWriterInstrument(value: "b")

        var context = ServiceContext.topLevel
        let dummy = DummyCarrier()

        // `MultiplexInstrument` runs every member in order, so both writers run and the last one wins for
        // the overlapping key.
        withInstrument(MultiplexInstrument([writerA, writerB])) {
            InstrumentationSystem.instrument.extract(dummy, into: &context, using: KeyWriterExtractor())
        }

        #expect(context[WrittenValueKey.self] == "b")
    }

    @Test("A MultiplexInstrument override fans out inject to all members, last member wins overlaps")
    func multiplexFansOutInject() {
        let writerA = KeyWriterInstrument(value: "a")
        let writerB = KeyWriterInstrument(value: "b")

        var carrier = DummyCarrier()

        withInstrument(MultiplexInstrument([writerA, writerB])) {
            InstrumentationSystem.instrument.inject(
                ServiceContext.topLevel,
                into: &carrier,
                using: KeyWriterInjector()
            )
        }

        #expect(carrier.value == "b")
    }

    // MARK: - Self-reference guard

    // `withInstrument` crashes if handed `InstrumentationSystem.instrument` (the scoping wrapper), directly
    // or nested in a `MultiplexInstrument`, since re-installing it would recurse forever. The crash itself
    // is a `fatalError` (not covered here); these cover the detection that drives it.

    @Test("Self-reference detection finds the scoping instrument directly and nested in a MultiplexInstrument")
    func detectsSelfReference() {
        #expect(TaskLocalInstrument.isOrContainsScopingInstrument(TaskLocalInstrument()))
        #expect(
            TaskLocalInstrument.isOrContainsScopingInstrument(
                MultiplexInstrument([NoOpInstrument(), MultiplexInstrument([TaskLocalInstrument()])])
            )
        )
    }

    @Test("Self-reference detection passes instruments that don't contain the scoping wrapper")
    func detectsNonSelfReference() {
        #expect(!TaskLocalInstrument.isOrContainsScopingInstrument(TestTracer()))
        #expect(
            !TaskLocalInstrument.isOrContainsScopingInstrument(
                MultiplexInstrument([NoOpInstrument(), TestTracer()])
            )
        )
    }

    // MARK: - Async

    @Test("withInstrument(_:_:) works with async closures")
    func withScopeAsync() async {
        let testTracer = TestTracer()

        await withInstrument(testTracer) {
            #expect(InstrumentationSystem.tracer is TestTracer)
        }
    }

    @Test("withSpan uses scoped tracer in async context")
    func withSpanAsyncUsesScopedTracer() async {
        let testTracer = TestTracer()

        await withInstrument(testTracer) {
            await withSpan("async-operation") { span in
                span.attributes["async"] = true
            }
        }

        #expect(testTracer.spans.count == 1)
        #expect(testTracer.spans.first?.operationName == "async-operation")
    }

    // MARK: - Sibling scope isolation

    @Test("Sibling withInstrument(_:_:) scopes in the same parent task are isolated")
    func siblingScopesAreIsolated() async {
        let tracer1 = TestTracer()
        let tracer2 = TestTracer()

        async let r1: Void = withInstrument(tracer1) {
            await Task.yield()
            await withSpan("span-a") { _ in }
        }
        async let r2: Void = withInstrument(tracer2) {
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

    @Test("withInstrument(_:_:) propagates errors from sync closures")
    func withScopePropagatesSyncErrors() {
        let tracer = TestTracer()

        do {
            try withInstrument(tracer) {
                throw ExampleSpanError()
            }
            Issue.record("Should have thrown")
        } catch {
            #expect(error is ExampleSpanError)
        }
    }

    @Test("withInstrument(_:_:) propagates errors from async closures")
    func withScopePropagatesAsyncErrors() async {
        let tracer = TestTracer()

        do {
            try await withInstrument(tracer) {
                throw ExampleSpanError()
            }
            Issue.record("Should have thrown")
        } catch {
            #expect(error is ExampleSpanError)
        }
    }

    @Test("withInstrument(_:_:) forwards typed throws without hitting the force-cast path")
    func withScopeTypedThrowsRoundTrip() async {
        let tracer = TestTracer()

        // Both the sync and async overloads take a `throws(Failure)` closure. If `withValue` ever forwarded
        // an error whose type was not exactly `Failure`, the internal `throw error as! Failure` would trap.
        func typedThrower() throws(ExampleSpanError) {
            throw ExampleSpanError()
        }

        var caught: ExampleSpanError?
        do {
            try withInstrument(tracer) { () throws(ExampleSpanError) in
                try typedThrower()
            }
        } catch {
            caught = error
        }
        #expect(caught != nil)

        var caughtAsync: ExampleSpanError?
        do {
            try await withInstrument(tracer) { () async throws(ExampleSpanError) in
                try typedThrower()
            }
        } catch {
            caughtAsync = error
        }
        #expect(caughtAsync != nil)
    }

    // MARK: - Return value forwarding

    @Test("withInstrument(_:_:) returns value from sync closure")
    func withScopeReturnsValueSync() {
        let tracer = TestTracer()

        let result = withInstrument(tracer) {
            42
        }

        #expect(result == 42)
    }

    @Test("withInstrument(_:_:) returns value from async closure")
    func withScopeReturnsValueAsync() async {
        let tracer = TestTracer()

        let result = await withInstrument(tracer) {
            "async-result"
        }

        #expect(result == "async-result")
    }

    // MARK: - Task propagation

    @Test("Task.detached does not inherit scoped instrument")
    func detachedTaskDoesNotInherit() async {
        let testTracer = TestTracer()

        await withInstrument(testTracer) {
            #expect(InstrumentationSystem.tracer is TestTracer)

            let resolvedInDetached = await Task.detached {
                InstrumentationSystem.tracer
            }.value

            #expect(resolvedInDetached is NoOpTracer)
        }
    }

    @Test("Unstructured Task inherits scoped instrument")
    func unstructuredTaskInheritsInstrument() async {
        let testTracer = TestTracer()

        let resolved = await withInstrument(testTracer) {
            await Task {
                InstrumentationSystem.tracer
            }.value
        }

        #expect(resolved is TestTracer)
    }

    @Test("Structured child tasks inherit scoped instrument")
    func structuredChildTasksInheritInstrument() async {
        let testTracer = TestTracer()

        await withInstrument(testTracer) {
            for i in 0..<3 {
                await withSpan("task-\(i)") { _ in }
            }
        }

        #expect(testTracer.spans.count == 3)
    }

    // MARK: - Lazy install of the scoping wrapper
    //
    // These reset to the default `NoOpInstrument` first to exercise the install-on-first-use path of
    // `withInstrument(_:_:)`. The crash path (a plain, non-scoping instrument was bootstrapped) is a
    // `fatalError` and is therefore not covered by an automated test.

    @Test("withInstrument lazily installs the scoping wrapper over an un-bootstrapped system")
    func lazilyInstallsWrapperOverNoOp() {
        InstrumentationSystem.bootstrapInternal(nil)
        #expect(InstrumentationSystem.instrument is NoOpInstrument)

        let testTracer = TestTracer()
        withInstrument(testTracer) {
            #expect(InstrumentationSystem.tracer as AnyObject === testTracer)
        }

        // The wrapper persists after the scope returns; only the scoped layer is unwound. With its inner
        // `NoOpInstrument` and no scope active, discovery falls back to NoOp.
        #expect(InstrumentationSystem.instrument is TaskLocalInstrument)
        #expect(InstrumentationSystem.tracer is NoOpTracer)
    }

    @Test("Repeated withInstrument calls reuse the installed wrapper")
    func repeatedCallsReuseInstalledWrapper() {
        InstrumentationSystem.bootstrapInternal(nil)

        withInstrument(TestTracer()) {}
        let afterFirst = InstrumentationSystem.instrument as? TaskLocalInstrument
        #expect(afterFirst != nil)

        withInstrument(TestTracer()) {}
        // Installing is idempotent: the second call reuses the same wrapper rather than installing a new one.
        #expect(InstrumentationSystem.instrument is TaskLocalInstrument)
    }
}

// MARK: - Fixtures for propagation precedence tests

/// `ServiceContext` key written by `KeyWriterInstrument` on extract.
private enum WrittenValueKey: ServiceContextKey {
    typealias Value = String
    static var nameOverride: String? { "written-value" }
}

/// Minimal carrier type with a single string slot.
private struct DummyCarrier: Sendable {
    var value: String?
}

/// Instrument that writes a fixed string to ``WrittenValueKey`` on `extract` and to the carrier's `value`
/// slot on `inject`.
private struct KeyWriterInstrument: Instrument {
    let value: String

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

/// Conforms to ``LegacyTracer`` only (no ``Tracer`` conformance), to verify that scoped resolution still
/// discovers a tracer predating the ``Tracer`` protocol — for example one nested in a `MultiplexInstrument`.
final class LegacyOnlyTestTracer: LegacyTracer, @unchecked Sendable {
    private(set) var startedOperationNames: [String] = []

    func startAnySpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> any Tracing.Span {
        self.startedOperationNames.append(operationName)
        return NoOpTracer.NoOpSpan(context: context())
    }

    func forceFlush() {}

    func extract<Carrier, Extract>(_ carrier: Carrier, into context: inout ServiceContext, using extractor: Extract)
    where Extract: Extractor, Extract.Carrier == Carrier {}

    func inject<Carrier, Inject>(_ context: ServiceContext, into carrier: inout Carrier, using injector: Inject)
    where Inject: Injector, Inject.Carrier == Carrier {}
}
