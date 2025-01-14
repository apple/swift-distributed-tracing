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
import Tracing
import XCTest

@testable @_spi(Locking) import Instrumentation

#if os(Linux) || os(Android)
@preconcurrency import Dispatch
#endif

final class TracerTests: XCTestCase {
    override class func tearDown() {
        super.tearDown()
        InstrumentationSystem.bootstrapInternal(nil)
    }

    func testContextPropagation() {
        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(NoOpTracer())
        }

        let httpServer = FakeHTTPServer { context, _, client -> FakeHTTPResponse in
            client.performRequest(context, request: FakeHTTPRequest(path: "/test", headers: []))
            return FakeHTTPResponse(status: 418)
        }

        httpServer.receive(FakeHTTPRequest(path: "/", headers: [("trace-id", "test")]))

        XCTAssertEqual(tracer.spans.count, 2)
        for span in tracer.spans {
            XCTAssertEqual(span.context.traceID, "test")
        }
    }

    func testContextPropagationWithNoOpSpan() {
        let httpServer = FakeHTTPServer { _, _, client -> FakeHTTPResponse in
            var context = ServiceContext.topLevel
            context.traceID = "test"
            client.performRequest(context, request: FakeHTTPRequest(path: "/test", headers: []))
            return FakeHTTPResponse(status: 418)
        }

        httpServer.receive(FakeHTTPRequest(path: "/", headers: [("trace-id", "test")]))

        XCTAssertEqual(httpServer.client.contexts.count, 1)
        XCTAssertEqual(httpServer.client.contexts.first?.traceID, "test")
    }

    func testWithSpan_success() {
        guard #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            return
        }
        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(NoOpTracer())
        }

        var spanEnded = false
        tracer.onEndSpan = { _ in
            spanEnded = true
        }

        let value = tracer.withSpan("hello", context: .topLevel) { _ in
            "yes"
        }

        XCTAssertEqual(value, "yes")
        XCTAssertTrue(spanEnded)
    }

    func testWithSpan_throws() {
        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(NoOpTracer())
        }

        var spanEnded = false
        tracer.onEndSpan = { _ in spanEnded = true }

        do {
            _ = try tracer.withAnySpan("hello", context: .topLevel) { _ in
                throw ExampleSpanError()
            }
        } catch {
            XCTAssertTrue(spanEnded)
            XCTAssertEqual(error as? ExampleSpanError, ExampleSpanError())
            return
        }
        XCTFail("Should have thrown")
    }

    func testWithSpan_automaticBaggagePropagation_sync() throws {
        #if canImport(_Concurrency)
        guard #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) else {
            throw XCTSkip("Task locals are not supported on this platform.")
        }

        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(nil)
        }

        var spanEnded = false
        tracer.onEndSpan = { _ in spanEnded = true }

        func operation(span: any Tracing.Span) -> String {
            "world"
        }

        let value = tracer.withAnySpan("hello") { (span: any Tracing.Span) -> String in
            XCTAssertEqual(span.context.traceID, ServiceContext.current?.traceID)
            return operation(span: span)
        }

        XCTAssertEqual(value, "world")
        XCTAssertTrue(spanEnded)
        #endif
    }

    func testWithSpan_automaticBaggagePropagation_sync_throws() throws {
        #if canImport(_Concurrency)
        guard #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) else {
            throw XCTSkip("Task locals are not supported on this platform.")
        }

        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(nil)
        }

        var spanEnded = false
        tracer.onEndSpan = { _ in spanEnded = true }

        func operation(span: any Tracing.Span) throws -> String {
            throw ExampleSpanError()
        }

        do {
            _ = try tracer.withAnySpan("hello", operation)
        } catch {
            XCTAssertTrue(spanEnded)
            XCTAssertEqual(error as? ExampleSpanError, ExampleSpanError())
            return
        }
        XCTFail("Should have thrown")
        #endif
    }

    func testWithSpan_automaticBaggagePropagation_async() throws {
        #if canImport(_Concurrency)
        guard #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) else {
            throw XCTSkip("Task locals are not supported on this platform.")
        }

        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(nil)
        }

        let spanEnded: LockedValueBox<Bool> = .init(false)
        tracer.onEndSpan = { _ in spanEnded.withValue { $0 = true } }

        let operation: @Sendable (any Tracing.Span) async throws -> String = { _ in
            "world"
        }

        try self.testAsync {
            let value = try await tracer.withAnySpan("hello") { (span: any Tracing.Span) -> String in
                XCTAssertEqual(span.context.traceID, ServiceContext.current?.traceID)
                return try await operation(span)
            }

            XCTAssertEqual(value, "world")
            XCTAssertTrue(spanEnded.withValue { $0 })
        }
        #endif
    }

    func testWithSpan_enterFromNonAsyncCode_passBaggage_asyncOperation() throws {
        guard #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) else {
            throw XCTSkip("Task locals are not supported on this platform.")
        }

        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(nil)
        }

        let spanEnded: LockedValueBox<Bool> = .init(false)
        tracer.onEndSpan = { _ in spanEnded.withValue { $0 = true } }

        let operation: @Sendable (any Tracing.Span) async -> String = { _ in
            "world"
        }

        self.testAsync {
            var fromNonAsyncWorld = ServiceContext.topLevel
            fromNonAsyncWorld.traceID = "1234-5678"
            let value = await tracer.withAnySpan("hello", context: fromNonAsyncWorld) {
                (span: any Tracing.Span) -> String in
                XCTAssertEqual(span.context.traceID, ServiceContext.current?.traceID)
                XCTAssertEqual(span.context.traceID, fromNonAsyncWorld.traceID)
                return await operation(span)
            }

            XCTAssertEqual(value, "world")
            XCTAssertTrue(spanEnded.withValue { $0 })
        }
    }

    func testWithSpan_automaticBaggagePropagation_async_throws() throws {
        guard #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) else {
            throw XCTSkip("Task locals are not supported on this platform.")
        }

        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(nil)
        }

        let spanEnded: LockedValueBox<Bool> = .init(false)
        tracer.onEndSpan = { _ in spanEnded.withValue { $0 = true } }

        let operation: @Sendable (any Tracing.Span) async throws -> String = { _ in
            throw ExampleSpanError()
        }

        self.testAsync {
            do {
                _ = try await tracer.withAnySpan("hello", operation)
            } catch {
                XCTAssertTrue(spanEnded.withValue { $0 })
                XCTAssertEqual(error as? ExampleSpanError, ExampleSpanError())
                return
            }
            XCTFail("Should have thrown")
        }
    }

    func test_static_Tracer_withSpan_automaticBaggagePropagation_async_throws() throws {
        guard #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) else {
            throw XCTSkip("Task locals are not supported on this platform.")
        }

        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(nil)
        }

        let spanEnded: LockedValueBox<Bool> = .init(false)
        tracer.onEndSpan = { _ in spanEnded.withValue { $0 = true } }

        let operation: @Sendable (any Tracing.Span) async throws -> String = { _ in
            throw ExampleSpanError()
        }

        self.testAsync {
            do {
                _ = try await withSpan("hello", operation)
            } catch {
                XCTAssertTrue(spanEnded.withValue { $0 })
                XCTAssertEqual(error as? ExampleSpanError, ExampleSpanError())
                return
            }
            XCTFail("Should have thrown")
        }
    }

    func test_static_Tracer_withSpan_automaticBaggagePropagation_throws() throws {
        guard #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) else {
            throw XCTSkip("Task locals are not supported on this platform.")
        }

        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(nil)
        }

        let spanEnded: LockedValueBox<Bool> = .init(false)
        tracer.onEndSpan = { _ in spanEnded.withValue { $0 = true } }

        let operation: @Sendable (any Tracing.Span) async throws -> String = { _ in
            throw ExampleSpanError()
        }

        self.testAsync {
            do {
                _ = try await withSpan("hello", operation)
            } catch {
                XCTAssertTrue(spanEnded.withValue { $0 })
                XCTAssertEqual(error as? ExampleSpanError, ExampleSpanError())
                return
            }
            XCTFail("Should have thrown")
        }
    }

    func testWithSpan_recordErrorWithAttributes() throws {
        #if canImport(_Concurrency)
        guard #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) else {
            throw XCTSkip("Task locals are not supported on this platform.")
        }

        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(nil)
        }

        var endedSpan: TestSpan?
        tracer.onEndSpan = { span in endedSpan = span }

        let errorToThrow = ExampleSpanError()
        let attrsForError: SpanAttributes = ["attr": "value"]

        tracer.withAnySpan("hello") { span in
            span.recordError(errorToThrow, attributes: attrsForError)
        }

        XCTAssertTrue(endedSpan != nil)
        XCTAssertEqual(endedSpan!.recordedErrors.count, 1)
        let error = endedSpan!.recordedErrors.first!.0
        XCTAssertEqual(error as! ExampleSpanError, errorToThrow)
        let attrs = endedSpan!.recordedErrors.first!.1
        XCTAssertEqual(attrs, attrsForError)
        #endif
    }

    func testWithSpanSignatures() {
        let tracer = TestTracer()
        let clock = DefaultTracerClock()

        tracer.withSpan("") { _ in }
        tracer.withSpan("", at: clock.now) { _ in }
        tracer.withSpan("", context: .topLevel) { _ in }

        tracer.withAnySpan("") { _ in }
        tracer.withAnySpan("", at: clock.now) { _ in }
        tracer.withAnySpan("", context: .topLevel) { _ in }
    }

    func testWithSpanShouldNotMissPropagatingInstant() {
        let tracer = TestTracer()
        InstrumentationSystem.bootstrapInternal(tracer)
        defer {
            InstrumentationSystem.bootstrapInternal(nil)
        }

        let clock = DefaultTracerClock()

        let instant = clock.now
        withSpan("span", at: instant) { _ in }

        let span = tracer.spans.first!
        XCTAssertEqual(span.startTimestampNanosSinceEpoch, instant.nanosecondsSinceEpoch)
    }

    //    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    /// Helper method to execute async operations until we can use async tests (currently incompatible with the generated LinuxMain file).
    /// - Parameter operation: The operation to test.
    func testAsync(_ operation: @Sendable @escaping () async throws -> Void) rethrows {
        let group = DispatchGroup()
        group.enter()
        Task.detached {
            do {
                try await operation()
            } catch {
                throw error
            }
            group.leave()
        }
        group.wait()
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

    func receive(_ request: FakeHTTPRequest) {
        var context = ServiceContext.topLevel
        InstrumentationSystem.instrument.extract(request.headers, into: &context, using: HTTPHeadersExtractor())

        let span = InstrumentationSystem.tracer.startSpan("GET \(request.path)", context: context)

        let response = self.catchAllHandler(span.context, request, self.client)
        span.attributes["http.status"] = response.status

        span.end()
    }
}

// MARK: - Fake HTTP Client

final class FakeHTTPClient {
    private(set) var contexts = [ServiceContext]()

    func performRequest(_ context: ServiceContext, request: FakeHTTPRequest) {
        var request = request
        let span = InstrumentationSystem.legacyTracer.startAnySpan("GET \(request.path)", context: context)

        self.contexts.append(span.context)
        InstrumentationSystem.instrument.inject(context, into: &request.headers, using: HTTPHeadersInjector())
        span.end()
    }
}
