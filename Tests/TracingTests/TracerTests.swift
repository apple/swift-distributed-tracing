//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2021 Apple Inc. and the Swift Distributed Tracing project
// authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import Instrumentation
import InstrumentationBaggage
import Tracing
import XCTest

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
            XCTAssertEqual(span.baggage.traceID, "test")
        }
    }

    func testContextPropagationWithNoOpSpan() {
        let httpServer = FakeHTTPServer { _, _, client -> FakeHTTPResponse in
            var baggage = Baggage.topLevel
            baggage.traceID = "test"
            client.performRequest(baggage, request: FakeHTTPRequest(path: "/test", headers: []))
            return FakeHTTPResponse(status: 418)
        }

        httpServer.receive(FakeHTTPRequest(path: "/", headers: [("trace-id", "test")]))

        XCTAssertEqual(httpServer.client.baggages.count, 1)
        XCTAssertEqual(httpServer.client.baggages.first?.traceID, "test")
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

        #if swift(>=5.7.0)
        let value = tracer.withSpan("hello", baggage: .topLevel) { _ in
            "yes"
        }
        #else
        let value = tracer.withAnySpan("hello", baggage: .topLevel) { _ in
            "yes"
        }
        #endif

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
            _ = try tracer.withAnySpan("hello", baggage: .topLevel) { _ in
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
        #if swift(>=5.5) && canImport(_Concurrency)
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

        func operation(span: any Span) -> String {
            "world"
        }

        let value = tracer.withAnySpan("hello") { (span: any Span) -> String in
            XCTAssertEqual(span.baggage.traceID, Baggage.current?.traceID)
            return operation(span: span)
        }

        XCTAssertEqual(value, "world")
        XCTAssertTrue(spanEnded)
        #endif
    }

    func testWithSpan_automaticBaggagePropagation_sync_throws() throws {
        #if swift(>=5.5) && canImport(_Concurrency)
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

        func operation(span: any Span) throws -> String {
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
        #if swift(>=5.5) && canImport(_Concurrency)
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

        func operation(span: any Span) async throws -> String {
            "world"
        }

        try self.testAsync {
            let value = try await tracer.withAnySpan("hello") { (span: any Span) -> String in
                XCTAssertEqual(span.baggage.traceID, Baggage.current?.traceID)
                return try await operation(span: span)
            }

            XCTAssertEqual(value, "world")
            XCTAssertTrue(spanEnded)
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

        var spanEnded = false
        tracer.onEndSpan = { _ in spanEnded = true }

        func operation(span: any Span) async -> String {
            "world"
        }

        self.testAsync {
            var fromNonAsyncWorld = Baggage.topLevel
            fromNonAsyncWorld.traceID = "1234-5678"
            let value = await tracer.withAnySpan("hello", baggage: fromNonAsyncWorld) { (span: any Span) -> String in
                XCTAssertEqual(span.baggage.traceID, Baggage.current?.traceID)
                XCTAssertEqual(span.baggage.traceID, fromNonAsyncWorld.traceID)
                return await operation(span: span)
            }

            XCTAssertEqual(value, "world")
            XCTAssertTrue(spanEnded)
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

        var spanEnded = false
        tracer.onEndSpan = { _ in spanEnded = true }

        func operation(span: any Span) async throws -> String {
            throw ExampleSpanError()
        }

        self.testAsync {
            do {
                _ = try await tracer.withAnySpan("hello", operation)
            } catch {
                XCTAssertTrue(spanEnded)
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

        var spanEnded = false
        tracer.onEndSpan = { _ in spanEnded = true }

        func operation(span: any Span) async throws -> String {
            throw ExampleSpanError()
        }

        self.testAsync {
            do {
                _ = try await Tracer.withSpan("hello", operation)
            } catch {
                XCTAssertTrue(spanEnded)
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

        var spanEnded = false
        tracer.onEndSpan = { _ in spanEnded = true }

        func operation(span: any Span) throws -> String {
            throw ExampleSpanError()
        }

        self.testAsync {
            do {
                _ = try Tracer.withSpan("hello", operation)
            } catch {
                XCTAssertTrue(spanEnded)
                XCTAssertEqual(error as? ExampleSpanError, ExampleSpanError())
                return
            }
            XCTFail("Should have thrown")
        }
    }

    func testWithSpan_recordErrorWithAttributes() throws {
        #if swift(>=5.5) && canImport(_Concurrency)
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

    #if swift(>=5.5) && canImport(_Concurrency)
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    /// Helper method to execute async operations until we can use async tests (currently incompatible with the generated LinuxMain file).
    /// - Parameter operation: The operation to test.
    func testAsync(_ operation: @escaping () async throws -> Void) rethrows {
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
    #endif
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
    typealias Handler = (Baggage, FakeHTTPRequest, FakeHTTPClient) -> FakeHTTPResponse

    private let catchAllHandler: Handler
    let client: FakeHTTPClient

    init(catchAllHandler: @escaping Handler) {
        self.catchAllHandler = catchAllHandler
        self.client = FakeHTTPClient()
    }

    func receive(_ request: FakeHTTPRequest) {
        var baggage = Baggage.topLevel
        InstrumentationSystem.instrument.extract(request.headers, into: &baggage, using: HTTPHeadersExtractor())

        #if swift(>=5.7.0)
        let span = InstrumentationSystem.legacyTracer.startAnySpan("GET \(request.path)", baggage: baggage)
        #else
        let span = InstrumentationSystem.legacyTracer.startAnySpan("GET \(request.path)", baggage: baggage)
        #endif

        let response = self.catchAllHandler(span.baggage, request, self.client)
        span.attributes["http.status"] = response.status

        span.end()
    }
}

// MARK: - Fake HTTP Client

final class FakeHTTPClient {
    private(set) var baggages = [Baggage]()

    func performRequest(_ baggage: Baggage, request: FakeHTTPRequest) {
        var request = request
        #if swift(>=5.7.0)
        let span = InstrumentationSystem.legacyTracer.startAnySpan("GET \(request.path)", baggage: baggage)
        #else
        let span = InstrumentationSystem.legacyTracer.startAnySpan("GET \(request.path)", baggage: baggage)
        #endif
        self.baggages.append(span.baggage)
        InstrumentationSystem.instrument.inject(baggage, into: &request.headers, using: HTTPHeadersInjector())
        span.end()
    }
}
