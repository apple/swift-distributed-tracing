import ContextPropagation
import NIOHTTP1

public struct HTTPClientRequestPartWithContext {
    public let requestPart: HTTPClientRequestPart
    public let context: Context

    public init(requestPart: HTTPClientRequestPart, context: Context) {
        self.requestPart = requestPart
        self.context = context
    }
}
