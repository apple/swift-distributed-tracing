//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(Testing)
@_spi(Locking) import Instrumentation
import Testing
import Tracing
@_spi(Testing) import InMemoryTracing

@Suite("InMemoryTracer")
struct InMemoryTracerTests {
    @Test("Starts root span", arguments: [SpanKind.client, .consumer, .internal, .producer, .server])
    func rootSpan(kind: SpanKind) throws {
        let tracer = InMemoryTracer()
        let clock = DefaultTracerClock()

        let startInstant = clock.now
        var context = ServiceContext.topLevel
        context[UnrelatedContextKey.self] = 42

        #expect(tracer.activeSpan(identifiedBy: context) == nil)

        let span = tracer.startSpan("root", context: context, ofKind: kind, at: startInstant)

        #expect(span.isRecording == true)
        #expect(span.operationName == "root")
        #expect(span.spanContext == InMemorySpanContext(traceID: "trace-1", spanID: "span-1", parentSpanID: nil))
        #expect(tracer.finishedSpans.isEmpty)

        let activeSpan = try #require(tracer.activeSpan(identifiedBy: span.context))
        #expect(activeSpan.operationName == "root")

        let endInstant = clock.now
        span.end(at: endInstant)

        #expect(span.isRecording == false)
        #expect(tracer.activeSpan(identifiedBy: span.context) == nil)

        let finishedSpan = try #require(tracer.finishedSpans.first)
        #expect(finishedSpan.operationName == "root")
        #expect(finishedSpan.startInstant.nanosecondsSinceEpoch == startInstant.nanosecondsSinceEpoch)
        #expect(finishedSpan.endInstant.nanosecondsSinceEpoch == endInstant.nanosecondsSinceEpoch)
    }

    @Test("Starts child span")
    func childSpan() throws {
        let tracer = InMemoryTracer()
        var rootContext = ServiceContext.topLevel
        rootContext[UnrelatedContextKey.self] = 42

        #expect(tracer.activeSpan(identifiedBy: rootContext) == nil)

        let rootSpan = tracer.startSpan("root", context: rootContext)
        let childSpan = tracer.startSpan("child", context: rootSpan.context)
        #expect(childSpan.isRecording == true)
        #expect(childSpan.operationName == "child")
        #expect(
            childSpan.spanContext == InMemorySpanContext(traceID: "trace-1", spanID: "span-2", parentSpanID: "span-1")
        )
        #expect(tracer.finishedSpans.isEmpty)

        let activeSpan = try #require(tracer.activeSpan(identifiedBy: childSpan.context))
        #expect(activeSpan.operationName == "child")

        childSpan.end()
        #expect(childSpan.isRecording == false)
        #expect(tracer.activeSpan(identifiedBy: childSpan.context) == nil)
        let finishedChildSpan = try #require(tracer.finishedSpans.first)
        #expect(finishedChildSpan.operationName == "child")

        rootSpan.end()
        #expect(rootSpan.isRecording == false)
        #expect(tracer.activeSpan(identifiedBy: rootSpan.context) == nil)
        let finishedRootSpan = try #require(tracer.finishedSpans.last)
        #expect(finishedRootSpan.operationName == "root")
    }

    @Test("Records force flushes")
    func forceFlush() {
        let tracer = InMemoryTracer()
        #expect(tracer.numberOfForceFlushes == 0)

        for numberOfForceFlushes in 1...10 {
            tracer.forceFlush()
            #expect(tracer.numberOfForceFlushes == numberOfForceFlushes)
        }
    }

    @Suite("Context Propagation")
    struct ContextPropagationTests {
        @Test("Injects span context into carrier and records injection")
        func injectWithSpanContext() throws {
            let tracer = InMemoryTracer()
            var context = ServiceContext.topLevel
            let spanContext = InMemorySpanContext(
                traceID: "stub",
                spanID: "stub",
                parentSpanID: "stub"
            )
            context.inMemorySpanContext = spanContext

            var values = [String: String]()
            tracer.inject(context, into: &values, using: DictionaryInjector())

            #expect(values == [InMemoryTracer.traceIDKey: "stub", InMemoryTracer.spanIDKey: "stub"])

            let injection = try #require(tracer.performedContextInjections.first)
            #expect(injection.context.inMemorySpanContext == spanContext)
            #expect(injection.values == values)
        }

        @Test("Does not inject context without span context but records attempt")
        func injectWithoutSpanContext() throws {
            let tracer = InMemoryTracer()
            let context = ServiceContext.topLevel

            var values = [String: String]()
            tracer.inject(context, into: &values, using: DictionaryInjector())

            #expect(values.isEmpty)

            let injection = try #require(tracer.performedContextInjections.first)
            #expect(injection.context.inMemorySpanContext == nil)
            #expect(injection.values.isEmpty)
        }

        @Test("Extracts span context from carrier and records extraction")
        func extractWithValues() throws {
            let tracer = InMemoryTracer()
            var context = ServiceContext.topLevel

            let values = [InMemoryTracer.traceIDKey: "stub", InMemoryTracer.spanIDKey: "stub"]
            tracer.extract(values, into: &context, using: DictionaryExtractor())

            let spanContext = try #require(context.inMemorySpanContext)

            #expect(spanContext == InMemorySpanContext(traceID: "stub", spanID: "stub", parentSpanID: nil))

            let extraction = try #require(tracer.performedContextExtractions.first)
            #expect(extraction.carrier as? [String: String] == values)
            #expect(extraction.context.inMemorySpanContext == spanContext)
        }

        @Test("Does not extract span context without values but records extraction")
        func extractWithoutValues() throws {
            let tracer = InMemoryTracer()
            var context = ServiceContext.topLevel

            let values = ["foo": "bar"]
            tracer.extract(values, into: &context, using: DictionaryExtractor())

            #expect(context.inMemorySpanContext == nil)

            let extraction = try #require(tracer.performedContextExtractions.first)
            #expect(extraction.carrier as? [String: String] == values)
            #expect(extraction.context.inMemorySpanContext == nil)
        }
    }

    @Suite("Span operations")
    struct SpanOperationTests {
        @Test("Update operation name")
        func updateOperationName() {
            let span = InMemorySpan.stub
            #expect(span.operationName == "stub")

            span.operationName = "updated"

            #expect(span.operationName == "updated")
        }

        @Test("Set attributes")
        func setAttributes() throws {
            let span = InMemorySpan.stub
            #expect(span.attributes == [:])

            span.attributes["x"] = "foo"
            #expect(span.attributes == ["x": "foo"])

            span.attributes["y"] = 42
            #expect(span.attributes == ["x": "foo", "y": 42])
        }

        @Test("Add events")
        func addEvents() throws {
            let clock = DefaultTracerClock()
            let span = InMemorySpan.stub
            #expect(span.events == [])

            let event1 = SpanEvent(name: "e1", at: clock.now, attributes: ["foo": "1"])
            span.addEvent(event1)
            #expect(span.events == [event1])

            let event2 = SpanEvent(name: "e2", at: clock.now, attributes: ["foo": "2"])
            span.addEvent(event2)
            #expect(span.events == [event1, event2])
        }

        @Test("Add links")
        func addLinks() throws {
            let span = InMemorySpan.stub
            #expect(span.links.isEmpty)

            let spanContext1 = InMemorySpanContext(traceID: "1", spanID: "1", parentSpanID: nil)
            var context1 = ServiceContext.topLevel
            context1.inMemorySpanContext = spanContext1
            span.addLink(SpanLink(context: context1, attributes: ["foo": "1"]))
            let link1 = try #require(span.links.first)
            #expect(link1.context.inMemorySpanContext == spanContext1)
            #expect(link1.attributes == ["foo": "1"])

            let spanContext2 = InMemorySpanContext(traceID: "2", spanID: "2", parentSpanID: nil)
            var context2 = ServiceContext.topLevel
            context2.inMemorySpanContext = spanContext2
            span.addLink(SpanLink(context: context2, attributes: ["foo": "2"]))
            let link2 = try #require(span.links.last)
            #expect(link2.context.inMemorySpanContext == spanContext2)
            #expect(link2.attributes == ["foo": "2"])
        }

        @Test("Record errors")
        func recordErrors() throws {
            let clock = DefaultTracerClock()
            let span = InMemorySpan.stub
            #expect(span.errors.isEmpty)

            struct Error1: Error {}
            let instant1 = clock.now
            span.recordError(Error1(), attributes: ["foo": "1"], at: instant1)
            let error1 = try #require(span.errors.first)
            #expect(error1.attributes == ["foo": "1"])
            #expect(error1.error is Error1)
            #expect(error1.instant.nanosecondsSinceEpoch == instant1.nanosecondsSinceEpoch)

            struct Error2: Error {}
            let instant2 = clock.now
            span.recordError(Error2(), attributes: ["foo": "2"], at: instant2)
            let error2 = try #require(span.errors.last)
            #expect(error2.attributes == ["foo": "2"])
            #expect(error2.error is Error2)
            #expect(error2.instant.nanosecondsSinceEpoch == instant2.nanosecondsSinceEpoch)
        }

        @Test("Set status")
        func setStatus() {
            let span = InMemorySpan.stub
            #expect(span.status == nil)

            let status = SpanStatus(code: .ok, message: "42")
            span.setStatus(status)

            #expect(span.status == status)
        }

        @Test("End")
        func end() throws {
            let clock = DefaultTracerClock()
            let _finishedSpan = LockedValueBox<FinishedInMemorySpan?>(nil)

            let startInstant = clock.now
            let spanContext = InMemorySpanContext(traceID: "stub", spanID: "stub", parentSpanID: nil)
            let span = InMemorySpan(
                operationName: "stub",
                context: .topLevel,
                spanContext: spanContext,
                kind: .internal,
                startInstant: startInstant,
                onEnd: { span in
                    _finishedSpan.withValue { $0 = span }
                }
            )
            span.attributes["foo"] = "bar"
            span.addEvent("foo")
            let otherSpanContext = InMemorySpanContext(traceID: "other", spanID: "other", parentSpanID: nil)
            var otherContext = ServiceContext.topLevel
            otherContext.inMemorySpanContext = otherSpanContext
            span.addLink(SpanLink(context: otherContext, attributes: [:]))
            struct TestError: Error {}
            span.recordError(TestError())

            #expect(span.isRecording == true)

            let endInstant = clock.now
            span.end(at: endInstant)
            #expect(span.isRecording == false)

            let finishedSpan = try #require(_finishedSpan.withValue { $0 })
            #expect(finishedSpan.operationName == "stub")
            #expect(finishedSpan.spanContext == spanContext)
            #expect(finishedSpan.startInstant.nanosecondsSinceEpoch == startInstant.nanosecondsSinceEpoch)
            #expect(finishedSpan.endInstant.nanosecondsSinceEpoch == endInstant.nanosecondsSinceEpoch)
            #expect(finishedSpan.attributes == span.attributes)
            #expect(finishedSpan.events == span.events)
            #expect(finishedSpan.links.count == span.links.count)
            #expect(finishedSpan.errors.count == span.errors.count)
            #expect(finishedSpan.status == span.status)
        }
    }

    @Suite("ID Generator")
    struct IDGeneratorTests {
        @Test("Increments trace ID")
        func traceID() {
            let idGenerator = InMemoryTracer.IDGenerator.incrementing

            for i in 1...10 {
                #expect(idGenerator.nextTraceID() == "trace-\(i)")
            }
        }

        @Test("Increments span ID")
        func spanID() {
            let idGenerator = InMemoryTracer.IDGenerator.incrementing

            for i in 1...10 {
                #expect(idGenerator.nextSpanID() == "span-\(i)")
            }
        }
    }

    @Suite("End to end")
    struct EndToEndTests {
        @Test("Parent/child span relationship across boundary")
        func parentChild() async throws {
            let idGenerator = InMemoryTracer.IDGenerator.incrementing
            let clientTracer = InMemoryTracer(idGenerator: idGenerator)
            let serverTracer = InMemoryTracer(idGenerator: idGenerator)

            let clientSpan = clientTracer.startSpan("client", ofKind: .client)
            #expect(clientSpan.spanContext.traceID == "trace-1")
            #expect(clientSpan.spanContext.spanID == "span-1")
            #expect(clientSpan.spanContext.parentSpanID == nil)

            // simulate injecting/extracting HTTP headers
            var headers = [String: String]()
            clientTracer.inject(clientSpan.context, into: &headers, using: DictionaryInjector())
            var serverContext = ServiceContext.topLevel
            serverTracer.extract(headers, into: &serverContext, using: DictionaryExtractor())

            let serverSpan = serverTracer.startSpan("server", context: serverContext, ofKind: .server)
            #expect(serverSpan.spanContext.traceID == clientSpan.spanContext.traceID)
            #expect(serverSpan.spanContext.spanID == "span-2")
            #expect(serverSpan.spanContext.parentSpanID == clientSpan.spanContext.spanID)
        }
    }

    @Test("Span can't be ended repeatedly")
    func inMemoryDoubleEnd() async {
        let endCounter = LockedValueBox<Int>(0)
        let span = InMemorySpan.stub { finished in
            endCounter.withValue { counter in
                counter += 1
                #expect(counter < 2, "Must not end() a span multiple times.")
            }
        }
        span.setStatus(SpanStatus(code: .ok))

        let clock = MockClock()
        clock.setTime(111)
        span.end()

        clock.setTime(222)
        span.end(at: clock.now)  // should not blow up, but also, not update time again

        #expect(endCounter.withValue { $0 } == 1)
    }
}

extension InMemorySpan {
    fileprivate static var stub: InMemorySpan {
        InMemorySpan(
            operationName: "stub",
            context: .topLevel,
            spanContext: InMemorySpanContext(traceID: "stub", spanID: "stub", parentSpanID: nil),
            kind: .internal,
            startInstant: DefaultTracerClock().now,
            onEnd: { _ in }
        )
    }

    fileprivate static func stub(onEnd: @Sendable @escaping (FinishedInMemorySpan) -> Void) -> InMemorySpan {
        InMemorySpan(
            operationName: "stub",
            context: .topLevel,
            spanContext: InMemorySpanContext(traceID: "stub", spanID: "stub", parentSpanID: nil),
            kind: .internal,
            startInstant: DefaultTracerClock().now,
            onEnd: onEnd
        )
    }
}

private struct DictionaryInjector: Injector {
    func inject(_ value: String, forKey key: String, into dictionary: inout [String: String]) {
        dictionary[key] = value
    }
}

private struct DictionaryExtractor: Extractor {
    func extract(key: String, from dictionary: [String: String]) -> String? {
        dictionary[key]
    }
}

private struct UnrelatedContextKey: ServiceContextKey {
    typealias Value = Int
}

private final class MockClock {
    var _now: UInt64 = 0

    init() {}

    func setTime(_ time: UInt64) {
        self._now = time
    }

    struct Instant: TracerInstant {
        var nanosecondsSinceEpoch: UInt64
        static func < (lhs: MockClock.Instant, rhs: MockClock.Instant) -> Bool {
            lhs.nanosecondsSinceEpoch < rhs.nanosecondsSinceEpoch
        }
    }

    var now: Instant {
        Instant(nanosecondsSinceEpoch: self._now)
    }
}

#endif
