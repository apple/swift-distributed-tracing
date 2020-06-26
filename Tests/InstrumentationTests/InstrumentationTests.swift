import Baggage
import Instrumentation
import XCTest

final class InstrumentTests: XCTestCase {
    func testMultiplexInvokesAllInstruments() {
        let instrument = MultiplexInstrument([
            AnyInstrument(FirstFakeTracer()),
            AnyInstrument(SecondFakeTracer()),
        ])

        var baggage = BaggageContext()
        let requestHeaders = [String: String]()
        instrument.extract(from: requestHeaders, into: &baggage)

        XCTAssertEqual(baggage[FirstFakeTracer.TraceID.self], FirstFakeTracer.defaultTraceID)

        var subsequentRequestHeaders = ["Accept": "application/json"]
        instrument.inject(from: baggage, into: &subsequentRequestHeaders)

        XCTAssertEqual(subsequentRequestHeaders, [
            "Accept": "application/json",
            FirstFakeTracer.headerName: FirstFakeTracer.defaultTraceID,
            SecondFakeTracer.headerName: SecondFakeTracer.defaultTraceID,
        ])
    }
}

private struct FirstFakeTracer: InstrumentProtocol {
    enum TraceID: BaggageContextKey {
        typealias Value = String
    }

    static let headerName = "first-fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    func inject(from baggage: BaggageContext, into headers: inout [String: String]) {
        headers[Self.headerName] = baggage[TraceID.self]
    }

    func extract(from headers: [String: String], into baggage: inout BaggageContext) {
        let traceID = headers.first(where: { $0.key == Self.headerName })?.value ?? Self.defaultTraceID
        baggage[TraceID.self] = traceID
    }
}

private struct SecondFakeTracer: InstrumentProtocol {
    enum TraceID: BaggageContextKey {
        typealias Value = String
    }

    static let headerName = "second-fake-trace-id"
    static let defaultTraceID = UUID().uuidString

    func inject(from baggage: BaggageContext, into headers: inout [String: String]) {
        headers[Self.headerName] = baggage[TraceID.self]
    }

    func extract(from headers: [String: String], into baggage: inout BaggageContext) {
        let traceID = headers.first(where: { $0.key == Self.headerName })?.value ?? Self.defaultTraceID
        baggage[TraceID.self] = traceID
    }
}
