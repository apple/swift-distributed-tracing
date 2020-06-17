import Baggage
import Logging

extension BaggageContext {
    public var logger: Logger {
        var logger = self[BaseLoggerKey.self] ?? Logger(label: "BaggageContext")
        // TODO: Filtering out a specific key to get rid of the logger seems very strange
        for (key, value) in baggageItems where key.keyType != BaseLoggerKey.self {
            logger[metadataKey: key.name] = "\(String(describing: value))"
        }
        return logger
    }
}

extension BaggageContext {
    public enum BaseLoggerKey: BaggageContextKey {
        public typealias Value = Logger
    }
}
