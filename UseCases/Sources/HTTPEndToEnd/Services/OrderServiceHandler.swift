import AsyncHTTPClient
import Baggage
import BaggageLogging
import Instrumentation
import Logging
import NIO
import NIOHTTP1

final class OrderServiceHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let httpClient: InstrumentedHTTPClient
    private let instrument: AnyInstrument<HTTPHeaders, HTTPHeaders>
    private let logger = Logger(label: "OrderService")

    init<Instrument>(httpClient: InstrumentedHTTPClient, instrument: Instrument)
        where
        Instrument: InstrumentProtocol,
        Instrument.InjectInto == HTTPHeaders,
        Instrument.ExtractFrom == HTTPHeaders {
        self.httpClient = httpClient
        self.instrument = AnyInstrument(instrument)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard case .head(let requestHead) = self.unwrapInboundIn(data) else { return }

        var baggage = BaggageContext()
        baggage[BaggageContext.BaseLoggerKey.self] = self.logger

        self.instrument.extract(from: requestHead.headers, into: &baggage)

        baggage.logger.info("🧾 Received order request")

        context.eventLoop.scheduleTask(in: .seconds(1)) {
            baggage.logger.info("🧾 Asking StorageService if your product exists")

            let request = try! HTTPClient.Request(url: "http://localhost:8081")
            self.httpClient.execute(request: request, baggage: baggage).whenComplete { _ in
                let responseHead = HTTPResponseHead(version: requestHead.version, status: .created)
                context.eventLoop.execute {
                    context.channel.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
                    context.channel.write(self.wrapOutboundOut(.end(nil)), promise: nil)
                    context.channel.flush()
                }
            }
        }
    }
}
