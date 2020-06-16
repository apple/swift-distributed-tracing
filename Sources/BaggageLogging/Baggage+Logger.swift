import Baggage
import Logging

extension BaggageContext {
    public var logger: Logger {
        var logger = self[BaseLoggerKey.self] ?? Logger(label: "BaggageContext")
        // TODO: Filtering out a specific key to get rid of the logger seems very strange
        for (key, value) in printableMetadata where key != String(describing: BaseLoggerKey.self) {
            logger[metadataKey: key] = "\(value)"
        }
        return logger
    }
}

extension BaggageContext {
    public enum BaseLoggerKey: BaggageContextKey {
        public typealias Value = Logger
    }
}
