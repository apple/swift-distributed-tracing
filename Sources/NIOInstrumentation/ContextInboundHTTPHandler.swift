import ContextPropagation
import NIO
import NIOHTTP1

public final class ContextInboundHTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias InboundOut = HTTPServerRequestPart

    private let instrumentationMiddleware: InstrumentationMiddleware<HTTPHeaders, HTTPHeaders>

    public init<Middleware>(instrumentationMiddleware: Middleware)
        where
        Middleware: InstrumentationMiddlewareProtocol,
        Middleware.InjectInto == HTTPHeaders,
        Middleware.ExtractFrom == HTTPHeaders {
        self.instrumentationMiddleware = InstrumentationMiddleware(instrumentationMiddleware)
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard case .head(let head) = unwrapInboundIn(data) else { return }
        self.instrumentationMiddleware.extract(from: head.headers, into: &.shared)
    }
}
