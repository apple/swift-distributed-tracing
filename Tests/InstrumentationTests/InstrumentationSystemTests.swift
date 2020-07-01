import Baggage
import Instrumentation
import XCTest

final class InstrumentationSystemTests: XCTestCase {
    func testItProvidesAccessToASingletonInstrument() {
        let tracer = FakeTracer()

        InstrumentationSystem.bootstrap(tracer)
        XCTAssertTrue(InstrumentationSystem.instrument as? FakeTracer === tracer)
    }
}

private final class FakeTracer: Instrument {
    enum TraceIDKey: BaggageContextKey {
        typealias Value = String
    }

    static let headerName = "fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    func inject<Carrier, Injector>(_ baggage: BaggageContext, into carrier: inout Carrier, using injector: Injector)
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier {}

    func extract<Carrier, Extractor>(_ carrier: Carrier, into baggage: inout BaggageContext, using extractor: Extractor)
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier {}
}
