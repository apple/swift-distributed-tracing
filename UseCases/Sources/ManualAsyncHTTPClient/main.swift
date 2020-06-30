import AsyncHTTPClient
import Baggage
import Foundation
import Instrumentation
import NIOHTTP1
import NIOInstrumentation

let server = FakeHTTPServer(
    instrument: FakeTracer()
) { context, _, client -> FakeHTTPResponse in
    print("=== Perform subsequent request ===")
    let outgoingRequest = try! HTTPClient.Request(
        url: "https://swift.org",
        headers: ["Accept": "application/json"]
    )
    client.execute(request: outgoingRequest, baggage: context)
    return FakeHTTPResponse()
}

print("=== Receive HTTP request on server ===")
server.receive(try! HTTPClient.Request(url: "https://swift.org"))

// MARK: - InstrumentedHTTPClient

struct InstrumentedHTTPClient {
    private let client = HTTPClient(eventLoopGroupProvider: .createNew)
    private let instrument: Instrument

    init(instrument: Instrument) {
        self.instrument = instrument
    }

    func execute(request: HTTPClient.Request, baggage: BaggageContext) {
        var request = request
        self.instrument.inject(baggage, into: &request.headers, using: HTTPHeadersInjector())
        print(request.headers)
    }
}

// MARK: - Fake HTTP Server

struct FakeHTTPResponse {}

struct FakeHTTPServer {
    typealias Handler = (BaggageContext, HTTPClient.Request, InstrumentedHTTPClient) -> FakeHTTPResponse

    private let instrument: Instrument
    private let catchAllHandler: Handler
    private let client: InstrumentedHTTPClient

    init(instrument: Instrument, catchAllHandler: @escaping Handler) {
        self.instrument = instrument
        self.catchAllHandler = catchAllHandler
        self.client = InstrumentedHTTPClient(instrument: instrument)
    }

    func receive(_ request: HTTPClient.Request) {
        var baggage = BaggageContext()
        print("\(String(describing: Self.self)): Extracting context values from request headers into context")
        self.instrument.extract(request.headers, into: &baggage, using: HTTPHeadersExtractor())
        _ = self.catchAllHandler(baggage, request, self.client)
    }
}

// MARK: - Fake Tracer

private final class FakeTracer: Instrument {
    enum TraceIDKey: BaggageContextKey {
        typealias Value = String
    }

    static let headerName = "fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    func inject<Carrier, Injector>(
        _ baggage: BaggageContext, into carrier: inout Carrier, using injector: Injector
    )
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier {
        guard let traceID = baggage[TraceIDKey.self] else { return }
        injector.inject(traceID, forKey: Self.headerName, into: &carrier)
    }

    func extract<Carrier, Extractor>(
        _ carrier: Carrier, into baggage: inout BaggageContext, using extractor: Extractor
    )
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier {
        let traceID = extractor.extract(key: Self.headerName, from: carrier) ?? Self.defaultTraceID
        baggage[TraceIDKey.self] = traceID
    }
}
