import Baggage
import Foundation
import Instrumentation
import NIOHTTP1

final class FakeTracer: Instrument {
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
