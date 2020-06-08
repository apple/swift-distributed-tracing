import ContextPropagation
import NIOHTTP1

struct FakeTracer {
    enum TraceID: ContextKey {
        typealias Value = String
    }

    static let headerName = "fake-trace-id"

    struct Middleware: InstrumentationMiddlewareProtocol {
        func extract(from headers: HTTPHeaders, into context: inout Context) {
            guard let traceID = headers.first(name: FakeTracer.headerName) else { return }
            context.inject(FakeTracer.TraceID.self, value: traceID)
        }

        func inject(from context: Context, into headers: inout HTTPHeaders) {
            guard let traceID = context.extract(FakeTracer.TraceID.self) else { return }
            headers.replaceOrAdd(name: FakeTracer.headerName, value: traceID)
        }
    }
}
