import Baggage

/// `InstrumentationSystem` is a global facility where the default cross-cutting tool can be configured.
/// It is set up just once in a given program select the desired `Instrument` implementation.
///
/// - Note: If you need to use more that one cross-cutting tool you can do so by using `MultiplexInstrument`.
public enum InstrumentationSystem {
    private static let lock = ReadWriteLock()
    private static var _instrument: Instrument = NOOPInstrument.instance
    private static var isInitialized = false

    /// Globally select the desired `Instrument` implementation.
    ///
    /// - Parameter instrument: The `Instrument` you want to share globally within your system.
    /// - Warning: Do not call this method more than once. This will lead to a crash.
    public static func bootstrap(_ instrument: Instrument) {
        self.lock.withWriterLock {
            precondition(
                !self.isInitialized, """
                InstrumentationSystem can only be initialized once per process. Consider using MultiplexInstrument if
                you need to use multiple instruments.
                """
            )
            self._instrument = instrument
            self.isInitialized = true
        }
    }

    /// Returns the globally configured `Instrument`. Defaults to a no-op `Instrument` if `boostrap` wasn't called before.
    public static var instrument: Instrument {
        self.lock.withReaderLock { self._instrument }
    }
}

private final class NOOPInstrument: Instrument {
    static let instance = NOOPInstrument()

    func inject<Carrier, Injector>(_ baggage: BaggageContext, into carrier: inout Carrier, using injector: Injector)
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier {}

    func extract<Carrier, Extractor>(_ carrier: Carrier, into baggage: inout BaggageContext, using extractor: Extractor)
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier {}
}
