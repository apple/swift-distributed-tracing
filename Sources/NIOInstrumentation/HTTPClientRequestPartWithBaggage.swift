import BaggageContext
import NIOHTTP1

public struct HTTPClientRequestPartWithBaggage {
    public let requestPart: HTTPClientRequestPart
    public let baggage: BaggageContext

    public init(requestPart: HTTPClientRequestPart, baggage: BaggageContext) {
        self.requestPart = requestPart
        self.baggage = baggage
    }
}
