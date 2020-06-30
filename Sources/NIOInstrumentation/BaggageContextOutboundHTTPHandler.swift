import Baggage
import Instrumentation
import NIO
import NIOHTTP1

public final class BaggageContextOutboundHTTPHandler: ChannelOutboundHandler {
    public typealias OutboundIn = HTTPClientRequestPartWithBaggage
    public typealias OutboundOut = HTTPClientRequestPart

    private let instrument: Instrument

    public init(instrument: Instrument) {
        self.instrument = instrument
    }

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let requestPartWithBaggage = unwrapOutboundIn(data)
        guard case .head(var head) = requestPartWithBaggage.requestPart else { return }
        self.instrument.inject(requestPartWithBaggage.baggage, into: &head.headers, using: HTTPHeadersInjector())
        // TODO: context.baggage = baggage
        // consider how we'll offer this capability in NIO
        context.write(self.wrapOutboundOut(.head(head)), promise: promise)
    }
}

public struct HTTPClientRequestPartWithBaggage {
    public let requestPart: HTTPClientRequestPart
    public let baggage: BaggageContext

    public init(requestPart: HTTPClientRequestPart, baggage: BaggageContext) {
        self.requestPart = requestPart
        self.baggage = baggage
    }
}
