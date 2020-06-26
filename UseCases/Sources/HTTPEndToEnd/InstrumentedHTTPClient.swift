import AsyncHTTPClient
import Baggage
import BaggageLogging
import Instrumentation
import NIO
import NIOHTTP1

struct InstrumentedHTTPClient {
    private let client: HTTPClient
    private let instrument: AnyInstrument<HTTPHeaders, HTTPHeaders>

    init<Instrument>(instrument: Instrument, eventLoopGroupProvider: HTTPClient.EventLoopGroupProvider)
        where
        Instrument: InstrumentProtocol,
        Instrument.InjectInto == HTTPHeaders,
        Instrument.ExtractFrom == HTTPHeaders {
        self.client = HTTPClient(eventLoopGroupProvider: eventLoopGroupProvider)
        self.instrument = AnyInstrument(instrument)
    }

    // TODO: deadline: NIODeadline? would move into baggage?
    public func get(url: String, baggage: BaggageContext = .init()) -> EventLoopFuture<HTTPClient.Response> {
        do {
            let request = try HTTPClient.Request(url: url, method: .GET)
            return self.execute(request: request, baggage: baggage)
        } catch {
            return self.client.eventLoopGroup.next().makeFailedFuture(error)
        }
    }

    func execute(request: HTTPClient.Request, baggage: BaggageContext) -> EventLoopFuture<HTTPClient.Response> {
        var request = request
        self.instrument.inject(from: baggage, into: &request.headers)
        baggage.logger.info("🌎 InstrumentedHTTPClient: Execute request")
        return self.client.execute(request: request)
    }

    func syncShutdown() throws {
        try self.client.syncShutdown()
    }
}
