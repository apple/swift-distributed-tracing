import ContextPropagation

extension Context {
    /// Singleton `Context` instance to be used in `NIO` until we can pass around `Context` through `NIO`.
    public static var shared = Context()
}
