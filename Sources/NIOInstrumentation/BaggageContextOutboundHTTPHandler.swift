import Baggage
import Instrumentation
import NIO
import NIOHTTP1

public final class BaggageContextOutboundHTTPHandler: ChannelOutboundHandler {
    public typealias OutboundIn = HTTPClientRequestPartWithBaggage
    public typealias OutboundOut = HTTPClientRequestPart

    private let instrument: AnyInstrument<HTTPHeaders, HTTPHeaders>

    public init<Instrument>(instrument: Instrument)
        where
        Instrument: InstrumentProtocol,
        Instrument.InjectInto == HTTPHeaders,
        Instrument.ExtractFrom == HTTPHeaders {
        self.instrument = AnyInstrument(instrument)
    }

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let requestPartWithBaggage = unwrapOutboundIn(data)
        guard case .head(var head) = requestPartWithBaggage.requestPart else { return }
        self.instrument.inject(from: requestPartWithBaggage.baggage, into: &head.headers)
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
