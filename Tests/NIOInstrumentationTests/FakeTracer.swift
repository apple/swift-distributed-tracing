import Baggage
import Foundation
import Instrumentation
import NIOHTTP1

struct FakeTracer: InstrumentProtocol {
    enum TraceID: BaggageContextKey {
        typealias Value = String
    }

    static let headerName = "fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    func inject(from baggage: BaggageContext, into headers: inout HTTPHeaders) {
        if let traceID = baggage[TraceID.self] {
            headers.replaceOrAdd(name: Self.headerName, value: traceID)
        } else {
            headers.remove(name: Self.headerName)
        }
    }

    func extract(from headers: HTTPHeaders, into baggage: inout BaggageContext) {
        let traceID = headers.first(name: Self.headerName) ?? Self.defaultTraceID
        baggage[TraceID.self] = traceID
    }
}
