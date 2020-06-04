import AsyncHTTPClient
import ContextPropagation
import NIOHTTP1

let server = FakeHTTPServer(
    instrumentationMiddlewares: [FakeTracer.Middleware(tracer: FakeTracer())]
) { context, request, client -> FakeHTTPResponse in
    print("=== Perform subsequent request ===")
    let outgoingRequest = try! HTTPClient.Request(
        url: "https://swift.org",
        headers: ["Accept": "application/json"]
    )
    client.execute(context, request: outgoingRequest)
//    client.execute(request: outgoingRequest, inContext: context)
    return FakeHTTPResponse()
}

print("=== Receive HTTP request on server ===")
server.receive(try! HTTPClient.Request(url: "https://swift.org"))

// MARK: - InstrumentedHTTPClient

struct InstrumentedHTTPClient {
    private let client = HTTPClient(eventLoopGroupProvider: .createNew)
    private let instrumentationMiddlewares: [InstrumentationMiddleware<HTTPHeaders, HTTPHeaders>]

    init<M: InstrumentationMiddlewareProtocol>(
        instrumentationMiddlewares: [M]
    ) where M.InjectInto == HTTPHeaders, M.ExtractFrom == HTTPHeaders {
        self.instrumentationMiddlewares = instrumentationMiddlewares.map {
            InstrumentationMiddleware(extract: $0.extract, inject: $0.inject)
        }
    }

    func execute(request: HTTPClient.Request, inContext context: Context) {
        execute(context, request: request)
    }

    func execute(_ context: Context, request: HTTPClient.Request) {
        var request = request
        instrumentationMiddlewares.forEach { $0.inject(from: context, into: &request.headers) }
        print(request.headers)
//        client.execute(request: request)
    }
}

// MARK: - Fake HTTP Server

struct FakeHTTPResponse {}

private typealias HTTPHeadersInstrumentationMiddleware = InstrumentationMiddleware<HTTPHeaders, HTTPHeaders>

struct FakeHTTPServer {
    typealias Handler = (Context, HTTPClient.Request, InstrumentedHTTPClient) -> FakeHTTPResponse

    private let instrumentationMiddlewares: [InstrumentationMiddleware<HTTPHeaders, HTTPHeaders>]
    private let catchAllHandler: Handler
    private let client: InstrumentedHTTPClient

    init<M: InstrumentationMiddlewareProtocol>(
        instrumentationMiddlewares: [M],
        catchAllHandler: @escaping Handler
    ) where M.InjectInto == HTTPHeaders, M.ExtractFrom == HTTPHeaders {
        self.instrumentationMiddlewares = instrumentationMiddlewares.map {
            InstrumentationMiddleware(extract: $0.extract, inject: $0.inject)
        }
        self.client = InstrumentedHTTPClient(instrumentationMiddlewares: instrumentationMiddlewares)
        self.catchAllHandler = catchAllHandler
    }

    func receive(_ request: HTTPClient.Request) {
        var context = Context()
        print("\(String(describing: Self.self)): Extracting context values from request headers into context")
        instrumentationMiddlewares.forEach { $0.extract(from: request.headers, into: &context) }
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
