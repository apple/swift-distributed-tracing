import Baggage
import Foundation
import Instrumentation

// MARK: - Demo

let server = FakeHTTPServer(instrument: FakeTracer()) { baggage, _, client in
    print("=== Perform subsequent request ===")
    let outgoingRequest = FakeHTTPRequest(path: "/other-service", headers: [("Content-Type", "application/json")])
    client.performRequest(baggage, request: outgoingRequest)
    return FakeHTTPResponse()
}

print("=== Receive HTTP request on server ===")
server.receive(FakeHTTPRequest(path: "/", headers: []))

// MARK: - Fake HTTP Server

typealias HTTPHeaders = [(String, String)]

struct HTTPHeadersExtractor: ExtractorProtocol {
    func extract(key: String, from headers: HTTPHeaders) -> String? {
        headers.first(where: { $0.0 == key })?.1
    }
}

struct HTTPHeadersInjector: InjectorProtocol {
    func inject(_ value: String, forKey key: String, into headers: inout HTTPHeaders) {
        headers.append((key, value))
    }
}

struct FakeHTTPRequest {
    let path: String
    var headers: HTTPHeaders
}

struct FakeHTTPResponse {}

struct FakeHTTPServer {
    typealias Handler = (BaggageContext, FakeHTTPRequest, FakeHTTPClient) -> FakeHTTPResponse

    private let instrument: Instrument
    private let catchAllHandler: Handler
    private let client: FakeHTTPClient

    init(instrument: Instrument, catchAllHandler: @escaping Handler) {
        self.instrument = instrument
        self.catchAllHandler = catchAllHandler
        self.client = FakeHTTPClient(instrument: instrument)
    }

    func receive(_ request: FakeHTTPRequest) {
        var baggage = BaggageContext()
        print("\(String(describing: Self.self)): Extracting context values from request headers into context")
        self.instrument.extract(request.headers, into: &baggage, using: HTTPHeadersExtractor())
        _ = self.catchAllHandler(baggage, request, self.client)
    }
}

// MARK: - Fake HTTP Client

struct FakeHTTPClient {
    private let instrument: Instrument

    init(instrument: Instrument) {
        self.instrument = instrument
    }

    func performRequest(_ baggage: BaggageContext, request: FakeHTTPRequest) {
        var request = request
        print("\(String(describing: Self.self)): Injecting context values into request headers")
        self.instrument.inject(baggage, into: &request.headers, using: HTTPHeadersInjector())
        print(request)
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
