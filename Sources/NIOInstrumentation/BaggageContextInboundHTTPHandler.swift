import Baggage
import Instrumentation
import NIO
import NIOHTTP1

public final class BaggageContextInboundHTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias InboundOut = HTTPServerRequestPart

    private let instrument: Instrument
    private var onBaggageExtracted: (BaggageContext) -> Void

    public init(instrument: Instrument, onBaggage: @escaping (BaggageContext) -> Void) {
        self.instrument = instrument
        self.onBaggageExtracted = onBaggage
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard case .head(let head) = unwrapInboundIn(data) else { return }
        var baggage = BaggageContext()
        self.instrument.extract(head.headers, into: &baggage, using: HTTPHeadersExtractor())
        self.onBaggageExtracted(baggage)
    }
}
