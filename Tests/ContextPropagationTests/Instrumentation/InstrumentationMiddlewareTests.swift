import ContextPropagation
import XCTest

final class InstrumentationMiddlewareTests: XCTestCase {
    func testMultiplexInvokesAllMiddleware() {
        let middleware = MultiplexInstrumentationMiddleware([
            InstrumentationMiddleware(FirstFakeTracer.Middleware()),
            InstrumentationMiddleware(SecondFakeTracer.Middleware())
        ])

        var context = Context()
        let requestHeaders = [String: String]()
        middleware.extract(from: requestHeaders, into: &context)

        XCTAssertEqual(context.extract(FirstFakeTracer.TraceID.self), FirstFakeTracer.defaultTraceID)
        XCTAssertEqual(context.extract(SecondFakeTracer.TraceID.self), SecondFakeTracer.defaultTraceID)

        var subsequentRequestHeaders = [String: String]()
        middleware.inject(from: context, into: &subsequentRequestHeaders)

        XCTAssertEqual(subsequentRequestHeaders, [
            FirstFakeTracer.headerName: FirstFakeTracer.defaultTraceID,
            SecondFakeTracer.headerName: SecondFakeTracer.defaultTraceID
        ])
    }
}

private struct FirstFakeTracer {
    enum TraceID: ContextKey {
        typealias Value = String
    }

    static let headerName = "first-fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    struct Middleware: InstrumentationMiddlewareProtocol {

        func extract(from headers: [String: String], into context: inout Context) {
            let traceID = headers.first(where: { $0.key == FirstFakeTracer.headerName })?.value ?? FirstFakeTracer.defaultTraceID
            context.inject(FirstFakeTracer.TraceID.self, value: traceID)
        }

        func inject(from context: Context, into headers: inout [String: String]) {
            headers[FirstFakeTracer.headerName] = context.extract(FirstFakeTracer.TraceID.self)
        }
    }
}

private struct SecondFakeTracer {
    enum TraceID: ContextKey {
        typealias Value = String
    }

    static let headerName = "second-fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    struct Middleware: InstrumentationMiddlewareProtocol {

        func extract(from headers: [String: String], into context: inout Context) {
            let traceID = headers.first(where: { $0.key == SecondFakeTracer.headerName })?.value ?? SecondFakeTracer.defaultTraceID
            context.inject(SecondFakeTracer.TraceID.self, value: traceID)
        }

        func inject(from context: Context, into headers: inout [String: String]) {
            headers[SecondFakeTracer.headerName] = context.extract(SecondFakeTracer.TraceID.self)
        }
    }
}
