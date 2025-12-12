//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift Distributed Tracing project authors
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

@testable @_spi(Locking) import Instrumentation

#if os(Linux) || os(Android)
@preconcurrency import Dispatch
#endif

@Suite("Tracer Tests")
struct TracerTests {
    @Test("Context propagation")
    func contextPropagation() {
        let tracer = TestTracer()
        let httpServer = FakeHTTPServer { context, _, client -> FakeHTTPResponse in
            client.performRequest(context, request: FakeHTTPRequest(path: "/test", headers: []), tracer: tracer)
            return FakeHTTPResponse(status: 418)
        }

        httpServer.receive(FakeHTTPRequest(path: "/", headers: [("trace-id", "test")]), tracer: tracer)

        #expect(tracer.spans.count == 2)
        for span in tracer.spans {
            #expect(span.context.traceID == "test")
        }
    }

    @Test("Context propagation with NoOp span")
    func contextPropagationWithNoOpSpan() {
        let tracer = TestTracer()
        let httpServer = FakeHTTPServer { _, _, client -> FakeHTTPResponse in
            var context = ServiceContext.topLevel
            context.traceID = "test"
            client.performRequest(context, request: FakeHTTPRequest(path: "/test", headers: []), tracer: tracer)
            return FakeHTTPResponse(status: 418)
        }

        httpServer.receive(FakeHTTPRequest(path: "/", headers: [("trace-id", "test")]), tracer: tracer)

        #expect(httpServer.client.contexts.count == 1)
        #expect(httpServer.client.contexts.first?.traceID == "test")
    }

    @Test("withSpan success")
    func withSpan_success() {
        let tracer = TestTracer()

        var spanEnded = false
        tracer.onEndSpan = { _ in
            spanEnded = true
        }

        let value = tracer.withSpan("hello", context: .topLevel) { _ in
            "yes"
        }

        #expect(value == "yes")
        #expect(spanEnded == true)
    }

    @Test("withSpan throws")
    func withSpan_throws() {
        let tracer = TestTracer()

        var spanEnded = false
        tracer.onEndSpan = { _ in spanEnded = true }

        do {
            _ = try tracer.withAnySpan("hello", context: .topLevel) { _ in
                throw ExampleSpanError()
            }
        } catch {
            #expect(spanEnded == true)
            #expect(error as? ExampleSpanError == ExampleSpanError())
            return
        }
        Issue.record("Should have thrown")
    }

    @Test("withSpan automatic context propagation (sync)")
    func withSpan_automaticBaggagePropagation_sync() throws {
        let tracer = TestTracer()

        var spanEnded = false
        tracer.onEndSpan = { _ in spanEnded = true }

        func operation(span: any Tracing.Span) -> String {
            "world"
        }

        let value = tracer.withAnySpan("hello") { (span: any Tracing.Span) -> String in
            #expect(span.context.traceID == ServiceContext.current?.traceID)
            return operation(span: span)
        }

        #expect(value == "world")
        #expect(spanEnded == true)
    }

    @Test("withSpan automatic context propagation (sync, throws)")
    func withSpan_automaticBaggagePropagation_sync_throws() throws {
        let tracer = TestTracer()

        var spanEnded = false
        tracer.onEndSpan = { _ in spanEnded = true }

        func operation(span: any Tracing.Span) throws -> String {
            throw ExampleSpanError()
        }

        do {
            _ = try tracer.withAnySpan("hello", operation)
        } catch {
            #expect(spanEnded == true)
            #expect(error as? ExampleSpanError == ExampleSpanError())
            return
        }
        Issue.record("Should have thrown")
    }

    @Test("withSpan automatic context propagation (async)")
    func withSpan_automaticBaggagePropagation_async() async throws {
        let tracer = TestTracer()

        let spanEnded: LockedValueBox<Bool> = .init(false)
        tracer.onEndSpan = { _ in spanEnded.withValue { $0 = true } }

        let operation: @Sendable (any Tracing.Span) async throws -> String = { _ in
            "world"
        }

        let value = try await tracer.withAnySpan("hello") { (span: any Tracing.Span) -> String in
            #expect(span.context.traceID == ServiceContext.current?.traceID)
            return try await operation(span)
        }

        #expect(value == "world")
        #expect(spanEnded.withValue { $0 } == true)
    }

    @Test("withSpan from non-async code with async operation")
    func withSpan_enterFromNonAsyncCode_passBaggage_asyncOperation() async throws {
        let tracer = TestTracer()

        let spanEnded: LockedValueBox<Bool> = .init(false)
        tracer.onEndSpan = { _ in spanEnded.withValue { $0 = true } }

        let operation: @Sendable (any Tracing.Span) async -> String = { _ in
            "world"
        }

        var fromNonAsyncWorld = ServiceContext.topLevel
        fromNonAsyncWorld.traceID = "1234-5678"
        let value = await tracer.withAnySpan("hello", context: fromNonAsyncWorld) {
            (span: any Tracing.Span) -> String in
            #expect(span.context.traceID == ServiceContext.current?.traceID)
            #expect(span.context.traceID == fromNonAsyncWorld.traceID)
            return await operation(span)
        }

        #expect(value == "world")
        #expect(spanEnded.withValue { $0 } == true)
    }

    @Test("withSpan automatic context propagation (async, throws)")
    func withSpan_automaticBaggagePropagation_async_throws() async throws {
        let tracer = TestTracer()

        let spanEnded: LockedValueBox<Bool> = .init(false)
        tracer.onEndSpan = { _ in spanEnded.withValue { $0 = true } }

        let operation: @Sendable (any Tracing.Span) async throws -> String = { _ in
            throw ExampleSpanError()
        }

        do {
            _ = try await tracer.withAnySpan("hello", operation)
        } catch {
            #expect(spanEnded.withValue { $0 } == true)
            #expect(error as? ExampleSpanError == ExampleSpanError())
            return
        }
        Issue.record("Should have thrown")
    }

    @Test("Static Tracer.withSpan automatic context propagation (async, throws)")
    func static_Tracer_withSpan_automaticBaggagePropagation_async_throws() async throws {
        let tracer = TestTracer()

        let spanEnded: LockedValueBox<Bool> = .init(false)
        tracer.onEndSpan = { _ in spanEnded.withValue { $0 = true } }

        let operation: @Sendable (any Tracing.Span) async throws -> String = { _ in
            throw ExampleSpanError()
        }

        do {
            _ = try await tracer.withSpan("hello", operation)
        } catch {
            #expect(spanEnded.withValue { $0 } == true)
            #expect(error as? ExampleSpanError == ExampleSpanError())
            return
        }
        Issue.record("Should have thrown")
    }

    @Test("Static Tracer.withSpan automatic context propagation (throws)")
    func static_Tracer_withSpan_automaticBaggagePropagation_throws() async throws {
        let tracer = TestTracer()

        let spanEnded: LockedValueBox<Bool> = .init(false)
        tracer.onEndSpan = { _ in spanEnded.withValue { $0 = true } }

        let operation: @Sendable (any Tracing.Span) async throws -> String = { _ in
            throw ExampleSpanError()
        }

        do {
            _ = try await tracer.withSpan("hello", operation)
        } catch {
            #expect(spanEnded.withValue { $0 } == true)
            #expect(error as? ExampleSpanError == ExampleSpanError())
            return
        }
        Issue.record("Should have thrown")
    }

    @Test("withSpan record error with attributes")
    func withSpan_recordErrorWithAttributes() throws {
        let tracer = TestTracer()

        var endedSpan: TestSpan?
        tracer.onEndSpan = { span in endedSpan = span }

        let errorToThrow = ExampleSpanError()
        let attrsForError: SpanAttributes = ["attr": "value"]

        tracer.withAnySpan("hello") { span in
            span.recordError(errorToThrow, attributes: attrsForError)
        }

        #expect(endedSpan != nil)
        #expect(endedSpan!.recordedErrors.count == 1)
        let error = endedSpan!.recordedErrors.first!.0
        #expect(error as! ExampleSpanError == errorToThrow)
        let attrs = endedSpan!.recordedErrors.first!.1
        #expect(attrs == attrsForError)
    }

    @Test("withSpan signatures")
    func withSpanSignatures() {
        let tracer = TestTracer()
        let clock = DefaultTracerClock()

        tracer.withSpan("") { _ in }
        tracer.withSpan("", at: clock.now) { _ in }
        tracer.withSpan("", context: .topLevel) { _ in }

        tracer.withAnySpan("") { _ in }
        tracer.withAnySpan("", at: clock.now) { _ in }
        tracer.withAnySpan("", context: .topLevel) { _ in }
    }

    @Test("withSpan should not miss propagating instant")
    func withSpanShouldNotMissPropagatingInstant() {
        let tracer = TestTracer()

        let clock = DefaultTracerClock()

        let instant = clock.now
        tracer.withSpan("span", at: instant) { _ in }

        let span = tracer.spans.first!
        #expect(span.startTimestampNanosSinceEpoch == instant.nanosecondsSinceEpoch)
    }
}

struct ExampleSpanError: Error, Equatable {}

// MARK: - Fake HTTP Server

typealias HTTPHeaders = [(String, String)]

struct HTTPHeadersExtractor: Extractor {
    func extract(key: String, from headers: HTTPHeaders) -> String? {
        headers.first(where: { $0.0 == key })?.1
    }
}

struct HTTPHeadersInjector: Injector {
    func inject(_ value: String, forKey key: String, into headers: inout HTTPHeaders) {
        headers.append((key, value))
    }
}

struct FakeHTTPRequest {
    let path: String
    var headers: HTTPHeaders
}

struct FakeHTTPResponse {
    let status: Int
}

struct FakeHTTPServer {
    typealias Handler = (ServiceContext, FakeHTTPRequest, FakeHTTPClient) -> FakeHTTPResponse

    private let catchAllHandler: Handler
    let client: FakeHTTPClient

    init(catchAllHandler: @escaping Handler) {
        self.catchAllHandler = catchAllHandler
        self.client = FakeHTTPClient()
    }

    func receive(_ request: FakeHTTPRequest, tracer: any Tracer & Instrument) {
        var context = ServiceContext.topLevel
        tracer.extract(request.headers, into: &context, using: HTTPHeadersExtractor())

        let span = tracer.startSpan("GET \(request.path)", context: context)

        let response = self.catchAllHandler(span.context, request, self.client)
        span.attributes["http.status"] = response.status

        span.end()
    }
}

// MARK: - Fake HTTP Client

final class FakeHTTPClient {
    private(set) var contexts = [ServiceContext]()

    func performRequest(_ context: ServiceContext, request: FakeHTTPRequest, tracer: any LegacyTracer) {
        var request = request
        let span = tracer.startAnySpan("GET \(request.path)", context: context)

        self.contexts.append(span.context)
        tracer.inject(context, into: &request.headers, using: HTTPHeadersInjector())
        span.end()
    }
}
