public protocol InstrumentationMiddlewareProtocol {
    associatedtype ExtractFrom
    associatedtype InjectInto

    func extract(from: ExtractFrom, into context: inout Context)
    func inject(from context: Context, into: inout InjectInto)
}

public struct InstrumentationMiddleware<InjectInto, ExtractFrom>: InstrumentationMiddlewareProtocol {
    private let extract: (ExtractFrom, inout Context) -> Void
    private let inject: (Context, inout InjectInto) -> Void

    public init<Middleware>(_ middleware: Middleware)
        where
        Middleware: InstrumentationMiddlewareProtocol,
        Middleware.InjectInto == InjectInto,
        Middleware.ExtractFrom == ExtractFrom {
            self.extract = middleware.extract
            self.inject = middleware.inject
    }

    public func extract(from: ExtractFrom, into context: inout Context) {
        self.extract(from, &context)
    }

    public func inject(from context: Context, into: inout InjectInto) {
        self.inject(context, &into)
    }
}
