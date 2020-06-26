import Baggage

/// A pseudo-`Instrument` that may be used to instrument using multiple other `AnyInstrument`s
/// across a common `BaggageContext`.
public struct MultiplexInstrument<InjectInto, ExtractFrom> {
    private var instruments: [AnyInstrument<InjectInto, ExtractFrom>]

    /// Create a `MultiplexInstrument`.
    ///
    /// - Parameter instruments: An array of `Instrument`s, each of which will be used to `inject`/`extract`
    /// through the same `BaggageContext`.
    public init(_ instruments: [AnyInstrument<InjectInto, ExtractFrom>]) {
        self.instruments = instruments
    }
}

extension MultiplexInstrument: InstrumentProtocol {
    public func inject(from baggage: BaggageContext, into: inout InjectInto) {
        self.instruments.forEach { $0.inject(from: baggage, into: &into) }
    }

    public func extract(from: ExtractFrom, into baggage: inout BaggageContext) {
        self.instruments.forEach { $0.extract(from: from, into: &baggage) }
    }
}
