import ContextPropagation
import NIO
import NIOHTTP1
import NIOInstrumentation
import XCTest

final class ContextInboundHTTPHandlerTests: XCTestCase {
    func testForwardsHTTPHeadersToInstrumentationMiddleware() throws {
        let traceID = "abc"
        let callbackExpectation = expectation(description: "Expected onContext to be called")

        var extractedContext: Context?
        let handler = ContextInboundHTTPHandler(instrumentationMiddleware: FakeTracer.Middleware()) { context in
            extractedContext = context
            callbackExpectation.fulfill()
        }
        let loop = EmbeddedEventLoop()
        let channel = EmbeddedChannel(handler: handler, loop: loop)
        var requestHead = HTTPRequestHead(version: .init(major: 1, minor: 1), method: .GET, uri: "/")
        requestHead.headers = [FakeTracer.headerName: traceID]

        try channel.writeInbound(HTTPServerRequestPart.head(requestHead))

        waitForExpectations(timeout: 0.5)

        XCTAssertNotNil(extractedContext)
        XCTAssertEqual(extractedContext!.extract(FakeTracer.TraceID.self), traceID)
    }
}
