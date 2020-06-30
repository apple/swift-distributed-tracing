import Baggage
import BaggageLogging
import Instrumentation
import Logging
import NIO
import NIOHTTP1
import NIOInstrumentation

final class StorageServiceHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let logger = Logger(label: "StorageService")
    private let instrument: Instrument

    init(instrument: Instrument) {
        self.instrument = instrument
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard case .head(let requestHead) = self.unwrapInboundIn(data) else { return }

        var baggage = BaggageContext()
        baggage[BaggageContext.BaseLoggerKey.self] = self.logger
        self.instrument.extract(requestHead.headers, into: &baggage, using: HTTPHeadersExtractor())

        baggage.logger.info("📦 Looking for the product")

        context.eventLoop.scheduleTask(in: .seconds(2)) {
            baggage.logger.info("📦 Found the product")
            let responseHead = HTTPResponseHead(version: requestHead.version, status: .ok)
            context.eventLoop.execute {
                context.channel.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
                context.channel.write(self.wrapOutboundOut(.end(nil)), promise: nil)
                context.channel.flush()
            }
        }
    }
}
