import ContextPropagation
import NIO
import NIOHTTP1
import NIOInstrumentation
import XCTest

final class ContextOutboundHTTPHandlerTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        Context.shared = Context()
    }

    func testUsesInstrumentationMiddlewareToInjectHTTPHeadersFromContext() throws {
        let traceID = "abc"
        Context.shared.inject(FakeTracer.TraceID.self, value: traceID)

        let httpVersion = HTTPVersion(major: 1, minor: 1)
        let handler = ContextOutboundHTTPHandler(instrumentationMiddleware: FakeTracer.Middleware())
        let loop = EmbeddedEventLoop()
        let channel = EmbeddedChannel(handler: handler, loop: loop)
        let requestHead = HTTPRequestHead(version: httpVersion, method: .GET, uri: "/")

        try channel.writeOutbound(HTTPClientRequestPart.head(requestHead))
        let modifiedRequestPart = try channel.readOutbound(as: HTTPClientRequestPart.self)

        let expectedRequestHead = HTTPRequestHead(
            version: httpVersion,
            method: .GET,
            uri: "/",
            headers: [FakeTracer.headerName: traceID]
        )
        XCTAssertEqual(modifiedRequestPart, .head(expectedRequestHead))
    }
}
