import ContextPropagation
import NIO
import NIOHTTP1
import NIOInstrumentation
import XCTest

final class NIOInstrumentationTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        Context.shared = Context()
    }

    func testForwardsHTTPHeadersToInstrumentationMiddleware() throws {
        let handler = ContextInboundHTTPHandler(instrumentationMiddleware: FakeTracer.Middleware())
        let loop = EmbeddedEventLoop()
        let channel = EmbeddedChannel(handler: handler, loop: loop)
        var requestHead = HTTPRequestHead(version: .init(major: 1, minor: 1), method: .GET, uri: "/")
        requestHead.headers = [FakeTracer.headerName: "abc"]

        try channel.writeInbound(HTTPServerRequestPart.head(requestHead))

        XCTAssertEqual(Context.shared.extract(FakeTracer.TraceID.self), "abc")
    }
}

private struct FakeTracer {
    enum TraceID: ContextKey {
        typealias Value = String
    }

    static let headerName = "fake-trace-id"

    struct Middleware: InstrumentationMiddlewareProtocol {
        func extract(from headers: HTTPHeaders, into context: inout Context) {
            guard let traceID = headers.first(name: FakeTracer.headerName) else { return }
            context.inject(FakeTracer.TraceID.self, value: traceID)
        }

        func inject(from context: Context, into headers: inout HTTPHeaders) {
            guard let traceID = context.extract(FakeTracer.TraceID.self) else { return }
            headers.replaceOrAdd(name: FakeTracer.headerName, value: traceID)
        }
    }
}
