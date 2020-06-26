import Baggage
import Foundation
import Instrumentation

// MARK: - Demo

let server = FakeHTTPServer(instrument: AnyInstrument(FakeTracer())) { baggage, _, client in
    print("=== Perform subsequent request ===")
    let outgoingRequest = FakeHTTPRequest(path: "/other-service", headers: [("Content-Type", "application/json")])
    client.performRequest(baggage, request: outgoingRequest)
    return FakeHTTPResponse()
}

print("=== Receive HTTP request on server ===")
server.receive(FakeHTTPRequest(path: "/", headers: []))

// MARK: - Fake HTTP Server

typealias HTTPHeaders = [(String, String)]

struct FakeHTTPRequest {
    let path: String
    var headers: HTTPHeaders
}

struct FakeHTTPResponse {}

typealias HTTPHeadersIntrument = AnyInstrument<HTTPHeaders, HTTPHeaders>

struct FakeHTTPServer {
    typealias Handler = (BaggageContext, FakeHTTPRequest, FakeHTTPClient) -> FakeHTTPResponse

    private let instrument: HTTPHeadersIntrument
    private let catchAllHandler: Handler
    private let client: FakeHTTPClient

    init<I>(instrument: I, catchAllHandler: @escaping Handler)
        where
        I: InstrumentProtocol,
        I.InjectInto == HTTPHeaders,
        I.ExtractFrom == HTTPHeaders {
        self.instrument = AnyInstrument(instrument)
        self.catchAllHandler = catchAllHandler
        self.client = FakeHTTPClient(instrument: instrument)
    }

    func receive(_ request: FakeHTTPRequest) {
        var baggage = BaggageContext()
        print("\(String(describing: Self.self)): Extracting context values from request headers into context")
        self.instrument.extract(from: request.headers, into: &baggage)
        _ = self.catchAllHandler(baggage, request, self.client)
    }
}

// MARK: - Fake HTTP Client

struct FakeHTTPClient {
    private let instrument: HTTPHeadersIntrument

    init<I>(instrument: I)
        where
        I: InstrumentProtocol,
        I.InjectInto == HTTPHeaders,
        I.ExtractFrom == HTTPHeaders {
        self.instrument = AnyInstrument(instrument)
    }

    func performRequest(_ baggage: BaggageContext, request: FakeHTTPRequest) {
        var request = request
        print("\(String(describing: Self.self)): Injecting context values into request headers")
        self.instrument.inject(from: baggage, into: &request.headers)
        print(request)
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
        headers.append((Self.headerName, traceID))
    }

    func extract(from headers: HTTPHeaders, into baggage: inout BaggageContext) {
        let traceID = headers.first(where: { $0.0 == Self.headerName })?.1 ?? Self.defaultTraceID
        baggage[TraceID.self] = traceID
    }
}
