import Baggage
import Logging

extension BaggageContext {
    public var logger: Logger {
        var logger = Logger(label: "BaggageContext")
        for (key, value) in printableMetadata {
            logger[metadataKey: key] = "\(value)"
        }
        return logger
    }
}
