import ContextPropagation
import NIO
import NIOHTTP1

public final class ContextOutboundHTTPHandler: ChannelOutboundHandler {
    public typealias OutboundIn = HTTPClientRequestPart
    public typealias OutboundOut = HTTPClientRequestPart

    private let instrumentationMiddleware: InstrumentationMiddleware<HTTPHeaders, HTTPHeaders>

    public init<Middleware>(instrumentationMiddleware: Middleware)
        where
        Middleware: InstrumentationMiddlewareProtocol,
        Middleware.InjectInto == HTTPHeaders,
        Middleware.ExtractFrom == HTTPHeaders {
        self.instrumentationMiddleware = InstrumentationMiddleware(instrumentationMiddleware)
    }

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        guard case .head(var head) = unwrapOutboundIn(data) else { return }
        self.instrumentationMiddleware.inject(from: .shared, into: &head.headers)
        context.write(self.wrapOutboundOut(.head(head)), promise: promise)
    }
}
