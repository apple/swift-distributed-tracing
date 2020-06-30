import Baggage
import Instrumentation
import NIO
import NIOHTTP1
import NIOInstrumentation
import XCTest

final class BaggageContextInboundHTTPHandlerTests: XCTestCase {
    func testForwardsHTTPHeadersToInstrumentationMiddleware() throws {
        let traceID = "abc"
        let callbackExpectation = expectation(description: "Expected onBaggageExtracted to be called")

        var extractedBaggage: BaggageContext?
        let handler = BaggageContextInboundHTTPHandler(instrument: FakeTracer()) { baggage in
            extractedBaggage = baggage
            callbackExpectation.fulfill()
        }
        let loop = EmbeddedEventLoop()
        let channel = EmbeddedChannel(handler: handler, loop: loop)
        var requestHead = HTTPRequestHead(version: .init(major: 1, minor: 1), method: .GET, uri: "/")
        requestHead.headers = [FakeTracer.headerName: traceID]

        try channel.writeInbound(HTTPServerRequestPart.head(requestHead))

        waitForExpectations(timeout: 0.5)

        XCTAssertNotNil(extractedBaggage)
        XCTAssertEqual(extractedBaggage![FakeTracer.TraceIDKey.self], traceID)
    }
}
