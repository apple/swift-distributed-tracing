import Instrumentation
import NIOHTTP1

public struct HTTPHeadersExtractor: ExtractorProtocol {
    public init() {}

    public func extract(key: String, from headers: HTTPHeaders) -> String? {
        headers.first(name: key)
    }
}

public struct HTTPHeadersInjector: InjectorProtocol {
    public init() {}

    public func inject(_ value: String, forKey key: String, into headers: inout HTTPHeaders) {
        headers.replaceOrAdd(name: key, value: value)
    }
}
