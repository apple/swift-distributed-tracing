import ContextPropagation

// MARK: - Demo

let server = FakeHTTPServer(
    instrumentationMiddlewares: [FakeTracer.Middleware(tracer: FakeTracer())]
) { context, request, client -> FakeHTTPResponse in
    print("=== Perform subsequent request ===")
    let outgoingRequest = FakeHTTPRequest(path: "/other-service", headers: [("Content-Type", "application/json")])
    client.performRequest(context, request: outgoingRequest)
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

typealias HTTPHeadersIntrumentationMiddleware = InstrumentationMiddleware<HTTPHeaders, HTTPHeaders>

struct FakeHTTPServer {
    typealias Handler = (Context, FakeHTTPRequest, FakeHTTPClient) -> FakeHTTPResponse

    private let instrumentationMiddlewares: [InstrumentationMiddleware<HTTPHeaders, HTTPHeaders>]
    private let catchAllHandler: Handler
    private let client: FakeHTTPClient

    init<M: InstrumentationMiddlewareProtocol>(
        instrumentationMiddlewares: [M],
        catchAllHandler: @escaping Handler
    ) where M.InjectInto == HTTPHeaders, M.ExtractFrom == HTTPHeaders {
        self.instrumentationMiddlewares = instrumentationMiddlewares.map {
            InstrumentationMiddleware(extract: $0.extract, inject: $0.inject)
        }
        self.catchAllHandler = catchAllHandler
        self.client = FakeHTTPClient(instrumentationMiddlewares: instrumentationMiddlewares)
    }

    func receive(_ request: FakeHTTPRequest) {
        var context = Context()
        print("\(String(describing: Self.self)): Extracting context values from request headers into context")
        instrumentationMiddlewares.forEach { $0.extract(from: request.headers, into: &context) }
        _ = catchAllHandler(context, request, client)
    }
}

// MARK: - Fake HTTP Client

struct FakeHTTPClient {
    private let instrumentationMiddlewares: [InstrumentationMiddleware<HTTPHeaders, HTTPHeaders>]

    init<M: InstrumentationMiddlewareProtocol>(
        instrumentationMiddlewares: [M]
    ) where M.InjectInto == HTTPHeaders, M.ExtractFrom == HTTPHeaders {
        self.instrumentationMiddlewares = instrumentationMiddlewares.map {
            InstrumentationMiddleware(extract: $0.extract, inject: $0.inject)
        }
    }

    func performRequest(_ context: Context, request: FakeHTTPRequest) {
        var request = request
        print("\(String(describing: Self.self)): Injecting context values into request headers")
        instrumentationMiddlewares.forEach { $0.inject(from: context, into: &request.headers) }
        print(request)
    }
}

// MARK: - Fake Tracer

struct FakeTracer {
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
            headers.append((FakeTraceID.headerName, traceID))
        }
    }

    private enum FakeTraceID: ContextKey {
        typealias Value = String

        static let headerName = "fake-trace-id"
    }
}
