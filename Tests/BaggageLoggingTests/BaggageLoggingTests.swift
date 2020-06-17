import Baggage
import BaggageLogging
import Logging
import XCTest

final class BaggageLoggingTests: XCTestCase {
    func testItAddsMetadataToTheLogger() {
        var context = BaggageContext()
        let simpleTraceID = 42
        context[SimpleTraceIDKey.self] = simpleTraceID
        let customTraceID = CustomTraceID(id: UUID(), name: "janedoe")
        context[CustomTraceIDKey.self] = customTraceID

        XCTAssertEqual(context.logger[metadataKey: "SimpleTraceIDKey"], "\(simpleTraceID)")
        XCTAssertEqual(context.logger[metadataKey: "MyTraceID"], "\(customTraceID)")
    }

    func testItUsesAnInjectedBaseLogger() {
        var logger = Logger(label: #function)
        logger.logLevel = .critical
        logger[metadataKey: "unit-testing"] = "\(true)"

        var context = BaggageContext()
        context[BaggageContext.BaseLoggerKey.self] = logger

        let simpleTraceID = 42
        context[SimpleTraceIDKey.self] = simpleTraceID

        XCTAssertEqual(context.logger.label, #function)
        XCTAssertEqual(context.logger.logLevel, .critical)
        XCTAssertEqual(context.logger[metadataKey: "unit-testing"], "\(true)")
        XCTAssertEqual(context.logger[metadataKey: "SimpleTraceIDKey"], "\(simpleTraceID)")
    }
}

enum SimpleTraceIDKey: BaggageContextKey {
    typealias Value = Int
}

struct CustomTraceID {
    let id: UUID
    let name: String
}

enum CustomTraceIDKey: BaggageContextKey {
    typealias Value = CustomTraceID
    static let name: String? = "MyTraceID"
}
