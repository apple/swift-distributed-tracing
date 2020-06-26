import Baggage
import Instrumentation
import NIO
import NIOHTTP1

public final class BaggageContextInboundHTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias InboundOut = HTTPServerRequestPart

    private let instrument: AnyInstrument<HTTPHeaders, HTTPHeaders>
    private var onBaggageExtracted: (BaggageContext) -> Void

    public init<Instrument>(instrument: Instrument, onBaggage: @escaping (BaggageContext) -> Void)
        where
        Instrument: InstrumentProtocol,
        Instrument.InjectInto == HTTPHeaders,
        Instrument.ExtractFrom == HTTPHeaders {
        self.instrument = AnyInstrument(instrument)
        self.onBaggageExtracted = onBaggage
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard case .head(let head) = unwrapInboundIn(data) else { return }
        var baggage = BaggageContext()
        self.instrument.extract(from: head.headers, into: &baggage)
        self.onBaggageExtracted(baggage)
    }
}
