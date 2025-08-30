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
@testable import TracingTestKit

@Suite("TestTracer")
struct TestTracerTests {
    @Test("Starts root span", arguments: [SpanKind.client, .consumer, .internal, .producer, .server])
    func rootSpan(kind: SpanKind) throws {
        let tracer = TestTracer()
        let clock = DefaultTracerClock()

        let startInstant = clock.now
        var context = ServiceContext.topLevel
        context[UnrelatedContextKey.self] = 42

        #expect(tracer.activeSpan(identifiedBy: context) == nil)

        let span = tracer.startSpan("root", context: context, ofKind: kind, at: startInstant)

        #expect(span.isRecording == true)
        #expect(span.operationName == "root")
        #expect(span.spanContext == TestSpanContext(traceID: "trace-1", spanID: "span-1", parentSpanID: nil))
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
        let tracer = TestTracer()
        var rootContext = ServiceContext.topLevel
        rootContext[UnrelatedContextKey.self] = 42

        #expect(tracer.activeSpan(identifiedBy: rootContext) == nil)

        let rootSpan = tracer.startSpan("root", context: rootContext)
        let childSpan = tracer.startSpan("child", context: rootSpan.context)
        #expect(childSpan.isRecording == true)
        #expect(childSpan.operationName == "child")
        #expect(childSpan.spanContext == TestSpanContext(traceID: "trace-1", spanID: "span-2", parentSpanID: "span-1"))
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
        let tracer = TestTracer()
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
            let tracer = TestTracer()
            var context = ServiceContext.topLevel
            let spanContext = TestSpanContext(
                traceID: "stub",
                spanID: "stub",
                parentSpanID: "stub"
            )
            context.testSpanContext = spanContext

            var values = [String: String]()
            tracer.inject(context, into: &values, using: DictionaryInjector())

            #expect(values == [TestTracer.traceIDKey: "stub", TestTracer.spanIDKey: "stub"])

            let injection = try #require(tracer.injections.first)
            #expect(injection.context.testSpanContext == spanContext)
            #expect(injection.values == values)
        }

        @Test("Does not inject context without span context but records attempt")
        func injectWithoutSpanContext() throws {
            let tracer = TestTracer()
            let context = ServiceContext.topLevel

            var values = [String: String]()
            tracer.inject(context, into: &values, using: DictionaryInjector())

            #expect(values.isEmpty)

            let injection = try #require(tracer.injections.first)
            #expect(injection.context.testSpanContext == nil)
            #expect(injection.values.isEmpty)
        }

        @Test("Extracts span context from carrier and records extraction")
        func extractWithValues() throws {
            let tracer = TestTracer()
            var context = ServiceContext.topLevel

            let values = [TestTracer.traceIDKey: "stub", TestTracer.spanIDKey: "stub"]
            tracer.extract(values, into: &context, using: DictionaryExtractor())

            let spanContext = try #require(context.testSpanContext)

            #expect(spanContext == TestSpanContext(traceID: "stub", spanID: "stub", parentSpanID: nil))

            let extraction = try #require(tracer.extractions.first)
            #expect(extraction.carrier as? [String: String] == values)
            #expect(extraction.context.testSpanContext == spanContext)
        }

        @Test("Does not extract span context without values but records extraction")
        func extractWithoutValues() throws {
            let tracer = TestTracer()
            var context = ServiceContext.topLevel

            let values = ["foo": "bar"]
            tracer.extract(values, into: &context, using: DictionaryExtractor())

            #expect(context.testSpanContext == nil)

            let extraction = try #require(tracer.extractions.first)
            #expect(extraction.carrier as? [String: String] == values)
            #expect(extraction.context.testSpanContext == nil)
        }
    }

    @Suite("Span operations")
    struct SpanOperationTests {
        @Test("Update operation name")
        func updateOperationName() {
            let span = TestSpan.stub
            #expect(span.operationName == "stub")

            span.operationName = "updated"

            #expect(span.operationName == "updated")
        }

        @Test("Set attributes")
        func setAttributes() throws {
            let span = TestSpan.stub
            #expect(span.attributes == [:])

            span.attributes["x"] = "foo"
            #expect(span.attributes == ["x": "foo"])

            span.attributes["y"] = 42
            #expect(span.attributes == ["x": "foo", "y": 42])
        }

        @Test("Add events")
        func addEvents() throws {
            let clock = DefaultTracerClock()
            let span = TestSpan.stub
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
            let span = TestSpan.stub
            #expect(span.links.isEmpty)

            let spanContext1 = TestSpanContext(traceID: "1", spanID: "1", parentSpanID: nil)
            var context1 = ServiceContext.topLevel
            context1.testSpanContext = spanContext1
            span.addLink(SpanLink(context: context1, attributes: ["foo": "1"]))
            let link1 = try #require(span.links.first)
            #expect(link1.context.testSpanContext == spanContext1)
            #expect(link1.attributes == ["foo": "1"])

            let spanContext2 = TestSpanContext(traceID: "2", spanID: "2", parentSpanID: nil)
            var context2 = ServiceContext.topLevel
            context2.testSpanContext = spanContext2
            span.addLink(SpanLink(context: context2, attributes: ["foo": "2"]))
            let link2 = try #require(span.links.last)
            #expect(link2.context.testSpanContext == spanContext2)
            #expect(link2.attributes == ["foo": "2"])
        }

        @Test("Record errors")
        func recordErrors() throws {
            let clock = DefaultTracerClock()
            let span = TestSpan.stub
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
            let span = TestSpan.stub
            #expect(span.status == nil)

            let status = SpanStatus(code: .ok, message: "42")
            span.setStatus(status)

            #expect(span.status == status)
        }

        @Test("End")
        func end() throws {
            let clock = DefaultTracerClock()
            let _finishedSpan = LockedValueBox<FinishedTestSpan?>(nil)

            let startInstant = clock.now
            let spanContext = TestSpanContext(traceID: "stub", spanID: "stub", parentSpanID: nil)
            let span = TestSpan(
                operationName: "stub",
                context: .topLevel,
                spanContext: spanContext,
                startInstant: startInstant,
                onEnd: { span in
                    _finishedSpan.withValue { $0 = span }
                }
            )
            span.attributes["foo"] = "bar"
            span.addEvent("foo")
            let otherSpanContext = TestSpanContext(traceID: "other", spanID: "other", parentSpanID: nil)
            var otherContext = ServiceContext.topLevel
            otherContext.testSpanContext = otherSpanContext
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
            let idGenerator = TestTracer.IDGenerator.incrementing

            for i in 1...10 {
                #expect(idGenerator.nextTraceID() == "trace-\(i)")
            }
        }

        @Test("Increments span ID")
        func spanID() {
            let idGenerator = TestTracer.IDGenerator.incrementing

            for i in 1...10 {
                #expect(idGenerator.nextSpanID() == "span-\(i)")
            }
        }
    }

    @Suite("End to end")
    struct EndToEndTests {
        @Test("Parent/child span relationship across boundary")
        func parentChild() async throws {
            let idGenerator = TestTracer.IDGenerator.incrementing
            let clientTracer = TestTracer(idGenerator: idGenerator)
            let serverTracer = TestTracer(idGenerator: idGenerator)

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

    #if compiler(>=6.2)  // Exit tests require Swift 6.2
    @Suite("TestSpan can't be mutated after being ended")
    struct FinishedSpanImmutability {
        @Test("Operation name is immutable on ended span")
        func operationName() async {
            await #expect(processExitsWith: .failure) {
                let span = TestSpan.stub
                span.operationName = "✅"

                span.end()

                span.operationName = "💥"
            }
        }

        @Test("Attributes are immutable on ended span")
        func attributes() async {
            await #expect(processExitsWith: .failure) {
                let span = TestSpan.stub
                span.attributes["before"] = "✅"

                span.end()

                span.attributes["after"] = "💥"
            }
        }

        @Test("Events are immutable on ended span")
        func events() async {
            await #expect(processExitsWith: .failure) {
                let span = TestSpan.stub
                span.addEvent("✅")

                span.end()

                span.addEvent("💥")
            }
        }

        @Test("Links are immutable on ended span")
        func links() async {
            await #expect(processExitsWith: .failure) {
                let span = TestSpan.stub
                span.addLink(.stub)

                span.end()

                span.addLink(.stub)
            }
        }

        @Test("Errors are immutable on ended span")
        func errors() async {
            await #expect(processExitsWith: .failure) {
                struct TestError: Error {}
                let span = TestSpan.stub
                span.recordError(TestError())

                span.end()

                span.recordError(TestError())
            }
        }

        @Test("Status is immutable on ended span")
        func status() async {
            await #expect(processExitsWith: .failure) {
                let span = TestSpan.stub
                span.setStatus(SpanStatus(code: .ok))

                span.end()

                span.setStatus(SpanStatus(code: .error))
            }
        }

        @Test("Span can't be ended repeatedly")
        func end() async {
            await #expect(processExitsWith: .failure) {
                let span = TestSpan.stub
                span.setStatus(SpanStatus(code: .ok))

                span.end()

                span.end()
            }
        }
    }
    #endif
}

extension TestSpan {
    fileprivate static var stub: TestSpan {
        TestSpan(
            operationName: "stub",
            context: .topLevel,
            spanContext: TestSpanContext(traceID: "stub", spanID: "stub", parentSpanID: nil),
            startInstant: DefaultTracerClock().now,
            onEnd: { _ in }
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
#endif
