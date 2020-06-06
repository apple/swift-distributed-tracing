import AsyncHTTPClient
import ContextPropagation
import NIOHTTP1

let server = FakeHTTPServer(
    instrumentationMiddleware: FakeTracer.Middleware(tracer: FakeTracer())
) { context, request, client -> FakeHTTPResponse in
    print("=== Perform subsequent request ===")
    let outgoingRequest = try! HTTPClient.Request(
        url: "https://swift.org",
        headers: ["Accept": "application/json"]
    )
    client.execute(request: outgoingRequest, context: context)
    return FakeHTTPResponse()
}

print("=== Receive HTTP request on server ===")
server.receive(try! HTTPClient.Request(url: "https://swift.org"))

// MARK: - InstrumentedHTTPClient

struct InstrumentedHTTPClient {
    private let client = HTTPClient(eventLoopGroupProvider: .createNew)
    private let instrumentationMiddleware: InstrumentationMiddleware<HTTPHeaders, HTTPHeaders>

    init<Middleware>(instrumentationMiddleware: Middleware)
        where
        Middleware: InstrumentationMiddlewareProtocol,
        Middleware.InjectInto == HTTPHeaders,
        Middleware.ExtractFrom == HTTPHeaders {
            self.instrumentationMiddleware = InstrumentationMiddleware(instrumentationMiddleware)
    }

    func execute(request: HTTPClient.Request, context: Context) {
        var request = request
        instrumentationMiddleware.inject(from: context, into: &request.headers)
        print(request.headers)
    }
}

// MARK: - Fake HTTP Server

struct FakeHTTPResponse {}

private typealias HTTPHeadersInstrumentationMiddleware = InstrumentationMiddleware<HTTPHeaders, HTTPHeaders>

struct FakeHTTPServer {
    typealias Handler = (Context, HTTPClient.Request, InstrumentedHTTPClient) -> FakeHTTPResponse

    private let instrumentationMiddleware: InstrumentationMiddleware<HTTPHeaders, HTTPHeaders>
    private let catchAllHandler: Handler
    private let client: InstrumentedHTTPClient

    init<Middleware>(instrumentationMiddleware: Middleware, catchAllHandler: @escaping Handler)
        where
        Middleware: InstrumentationMiddlewareProtocol,
        Middleware.InjectInto == HTTPHeaders,
        Middleware.ExtractFrom == HTTPHeaders {
            self.instrumentationMiddleware = InstrumentationMiddleware(instrumentationMiddleware)
            self.catchAllHandler = catchAllHandler
            self.client = InstrumentedHTTPClient(instrumentationMiddleware: instrumentationMiddleware)
    }

    func receive(_ request: HTTPClient.Request) {
        var context = Context()
        print("\(String(describing: Self.self)): Extracting context values from request headers into context")
        instrumentationMiddleware.extract(from: request.headers, into: &context)
        _ = catchAllHandler(context, request, client)
    }
}

// MARK: - Fake Tracer

private struct FakeTracer {
    func generateTraceID() -> String {
        "3f59ef6fe1fe2b12dd84ec1452696599"
    }

    struct Middleware: InstrumentationMiddlewareProtocol {
        private let tracer: FakeTracer

        init(tracer: FakeTracer) {
            self.tracer = tracer
        }

        func extract(from headers: HTTPHeaders, into context: inout Context) {
            let traceID = headers.first(where: { $0.0 == FakeTraceID.headerName })?.1 ?? tracer.generateTraceID()
            context.inject(FakeTraceID.self, value: traceID)
        }

        func inject(from context: Context, into headers: inout HTTPHeaders) {
            guard let traceID = context.extract(FakeTraceID.self) else { return }
            headers.add(name: FakeTraceID.headerName, value: traceID)
        }
    }

    private enum FakeTraceID: ContextKey {
        typealias Value = String

        static let headerName = "fake-trace-id"
    }
}
