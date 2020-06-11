import BaggageContext
import Instrumentation
import NIO
import NIOHTTP1

public final class BaggageContextInboundHTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias InboundOut = HTTPServerRequestPart

    private let instrument: Instrument<HTTPHeaders, HTTPHeaders>
    private var onBaggageExtracted: (BaggageContext) -> Void

    public init<I>(instrument: I, onBaggage: @escaping (BaggageContext) -> Void)
        where
        I: InstrumentProtocol,
        I.InjectInto == HTTPHeaders,
        I.ExtractFrom == HTTPHeaders {
        self.instrument = Instrument(instrument)
        self.onBaggageExtracted = onBaggage
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard case .head(let head) = unwrapInboundIn(data) else { return }
        var baggage = BaggageContext()
        self.instrument.extract(from: head.headers, into: &baggage)
        self.onBaggageExtracted(baggage)
    }
}
