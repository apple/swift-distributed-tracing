import AsyncHTTPClient
import Baggage
import Foundation
import Instrumentation
import NIOHTTP1

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
    private let instrument: AnyInstrument<HTTPHeaders, HTTPHeaders>

    init<Instrument>(instrument: Instrument)
        where
        Instrument: InstrumentProtocol,
        Instrument.InjectInto == HTTPHeaders,
        Instrument.ExtractFrom == HTTPHeaders {
        self.instrument = AnyInstrument(instrument)
    }

    func execute(request: HTTPClient.Request, baggage: BaggageContext) {
        var request = request
        self.instrument.inject(from: baggage, into: &request.headers)
        print(request.headers)
    }
}

// MARK: - Fake HTTP Server

struct FakeHTTPResponse {}

typealias HTTPHeadersIntrument = AnyInstrument<HTTPHeaders, HTTPHeaders>

struct FakeHTTPServer {
    typealias Handler = (BaggageContext, HTTPClient.Request, InstrumentedHTTPClient) -> FakeHTTPResponse

    private let instrument: HTTPHeadersIntrument
    private let catchAllHandler: Handler
    private let client: InstrumentedHTTPClient

    init<Instrument>(instrument: Instrument, catchAllHandler: @escaping Handler)
        where
        Instrument: InstrumentProtocol,
        Instrument.InjectInto == HTTPHeaders,
        Instrument.ExtractFrom == HTTPHeaders {
        self.instrument = AnyInstrument(instrument)
        self.catchAllHandler = catchAllHandler
        self.client = InstrumentedHTTPClient(instrument: instrument)
    }

    func receive(_ request: HTTPClient.Request) {
        var baggage = BaggageContext()
        print("\(String(describing: Self.self)): Extracting context values from request headers into context")
        self.instrument.extract(from: request.headers, into: &baggage)
        _ = self.catchAllHandler(baggage, request, self.client)
    }
}

// MARK: - Fake Tracer

private struct FakeTracer: InstrumentProtocol {
    enum TraceID: BaggageContextKey {
        typealias Value = String
    }

    static let headerName = "fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    func inject(from baggage: BaggageContext, into headers: inout HTTPHeaders) {
        guard let traceID = baggage[TraceID.self] else { return }
        headers.replaceOrAdd(name: Self.headerName, value: traceID)
    }

    func extract(from headers: HTTPHeaders, into baggage: inout BaggageContext) {
        let traceID = headers.first(where: { $0.0 == Self.headerName })?.1 ?? Self.defaultTraceID
        baggage[TraceID.self] = traceID
    }
}
