import ContextPropagation
import NIO
import NIOHTTP1

public final class ContextInboundHTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias InboundOut = HTTPServerRequestPart

    private let instrumentationMiddleware: InstrumentationMiddleware<HTTPHeaders, HTTPHeaders>
    private var onContext: ((Context) -> Void)?

    public init<Middleware>(instrumentationMiddleware: Middleware, onContext: @escaping (Context) -> Void)
        where
        Middleware: InstrumentationMiddlewareProtocol,
        Middleware.InjectInto == HTTPHeaders,
        Middleware.ExtractFrom == HTTPHeaders {
        self.instrumentationMiddleware = InstrumentationMiddleware(instrumentationMiddleware)
        self.onContext = onContext
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard case .head(let head) = unwrapInboundIn(data) else { return }
        var context = Context()
        self.instrumentationMiddleware.extract(from: head.headers, into: &context)
        self.onContext?(context)
    }
}
