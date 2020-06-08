import ContextPropagation
import NIO
import NIOHTTP1
import NIOInstrumentation
import XCTest

final class ContextInboundHTTPHandlerTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        Context.shared = Context()
    }

    func testForwardsHTTPHeadersToInstrumentationMiddleware() throws {
        let traceID = "abc"

        let handler = ContextInboundHTTPHandler(instrumentationMiddleware: FakeTracer.Middleware())
        let loop = EmbeddedEventLoop()
        let channel = EmbeddedChannel(handler: handler, loop: loop)
        var requestHead = HTTPRequestHead(version: .init(major: 1, minor: 1), method: .GET, uri: "/")
        requestHead.headers = [FakeTracer.headerName: traceID]

        try channel.writeInbound(HTTPServerRequestPart.head(requestHead))

        XCTAssertEqual(Context.shared.extract(FakeTracer.TraceID.self), traceID)
    }
}
