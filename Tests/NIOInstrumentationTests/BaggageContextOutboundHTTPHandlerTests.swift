import Baggage
import Instrumentation
import NIO
import NIOHTTP1
import NIOInstrumentation
import XCTest

final class BaggageContextOutboundHTTPHandlerTests: XCTestCase {
    func testUsesInstrumentationMiddlewareToInjectHTTPHeadersFromContext() throws {
        let traceID = "abc"

        var baggage = BaggageContext()
        baggage[FakeTracer.TraceIDKey.self] = traceID

        let httpVersion = HTTPVersion(major: 1, minor: 1)
        let handler = BaggageContextOutboundHTTPHandler(instrument: FakeTracer())
        let loop = EmbeddedEventLoop()
        let channel = EmbeddedChannel(handler: handler, loop: loop)
        let requestHead = HTTPRequestHead(version: httpVersion, method: .GET, uri: "/")

        try channel.writeOutbound(HTTPClientRequestPartWithBaggage(requestPart: .head(requestHead), baggage: baggage))
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
