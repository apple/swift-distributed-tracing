/// A pseudo-`InstrumentationMiddlewareProtocol` that can be used to instrument using multiple other `InstrumentationMiddleware`s across
/// a common `Context`.
public struct MultiplexInstrumentationMiddleware<InjectInto, ExtractFrom> {
    private var middlewares: [InstrumentationMiddleware<InjectInto, ExtractFrom>]

    /// Create a `MultiplexInstrumentationMiddleware`.
    ///
    /// - Parameter middlewares: An array of `InstrumentationMiddleware`s, each of which will be used to `extract` from and `inject` into
    /// a common `Context`.
    public init(_ middlewares: [InstrumentationMiddleware<InjectInto, ExtractFrom>]) {
        self.middlewares = middlewares
    }
}

extension MultiplexInstrumentationMiddleware: InstrumentationMiddlewareProtocol {
    public func extract(from: ExtractFrom, into context: inout Context) {
        self.middlewares.forEach { $0.extract(from: from, into: &context) }
    }

    public func inject(from context: Context, into: inout InjectInto) {
        self.middlewares.forEach { $0.inject(from: context, into: &into) }
    }
}
