import Baggage

/// Conforming types are usually cross-cutting tools like tracers that extract values of one type (`ExtractFrom`) into a
/// `BaggageContext` and inject values stored in a `BaggageContext` into another type (`InjectInto`).
/// `ExtractFrom` and `InjectInto` may very well be of the same type, e.g. when a cross-cutting tool propagates
/// baggage through HTTP headers.
public protocol InstrumentProtocol {
    associatedtype InjectInto
    associatedtype ExtractFrom

    /// Extract values from an `ExtractFrom` and inject them into the given `BaggageContext`.
    ///
    /// - Parameters:
    ///   - from: The value from which relevant information will be extracted.
    ///   - baggage: The `BaggageContext` in which this relevant information will be stored.
    func extract(from: ExtractFrom, into baggage: inout BaggageContext)

    /// Inject values into the given `InjectInto` which are stored in the given `BaggageContext`.
    ///
    /// - Parameters:
    ///   - baggage: The `BaggageContext` from which relevant information will be extracted.
    ///   - into: The `InjectInto` into which this information will be injected. In general, you shouldn't remove values from this
    ///   but only update/add, as other tools may be interested in the values you're about to remove.
    func inject(from baggage: BaggageContext, into: inout InjectInto)
}

/// A box-type for an `InstrumentProtocol`, necessary for creating homogeneous collections of `InstrumentProtocol`s.
public struct Instrument<InjectInto, ExtractFrom>: InstrumentProtocol {
    private let inject: (BaggageContext, inout InjectInto) -> Void
    private let extract: (ExtractFrom, inout BaggageContext) -> Void

    /// Wrap the given `InstrumentProtocol` inside an `Instrument`.
    /// - Parameter instrument: The `InstrumentProtocol` being wrapped.
    public init<I>(_ instrument: I)
        where
        I: InstrumentProtocol,
        I.InjectInto == InjectInto,
        I.ExtractFrom == ExtractFrom {
        self.inject = instrument.inject
        self.extract = instrument.extract
    }

    public func inject(from baggage: BaggageContext, into: inout InjectInto) {
        self.inject(baggage, &into)
    }

    public func extract(from: ExtractFrom, into baggage: inout BaggageContext) {
        self.extract(from, &baggage)
    }
}
