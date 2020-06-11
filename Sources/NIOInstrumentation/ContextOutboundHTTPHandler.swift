import ContextPropagation
import NIO
import NIOHTTP1

public final class ContextOutboundHTTPHandler: ChannelOutboundHandler {
    public typealias OutboundIn = HTTPClientRequestPartWithContext
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
        let requestPartWithBaggage = unwrapOutboundIn(data)
        guard case .head(var head) = requestPartWithBaggage.requestPart else { return }
        self.instrumentationMiddleware.inject(from: requestPartWithBaggage.context, into: &head.headers)
        // TODO: context.baggage = baggage
        // consider how we'll offer this capability in NIO
        context.write(self.wrapOutboundOut(.head(head)), promise: promise)
    }
}
