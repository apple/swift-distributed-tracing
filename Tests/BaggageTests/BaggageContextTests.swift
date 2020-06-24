import Baggage
import XCTest

final class BaggageContextTests: XCTestCase {
    func testSubscriptAccess() {
        let testID = 42

        var baggage = BaggageContext()
        XCTAssertNil(baggage[TestIDKey.self])

        baggage[TestIDKey.self] = testID
        XCTAssertEqual(baggage[TestIDKey], testID)

        baggage[TestIDKey.self] = nil
        XCTAssertNil(baggage[TestIDKey.self])
    }

    func testRecommendedConvenienceExtension() {
        let testID = 42

        var baggage = BaggageContext()
        XCTAssertNil(baggage.testID)

        baggage.testID = testID
        XCTAssertEqual(baggage.testID, testID)

        baggage[TestIDKey.self] = nil
        XCTAssertNil(baggage.testID)
    }

    func testEmptyBaggageDescription() {
        XCTAssertEqual(String(describing: BaggageContext()), "BaggageContext(keys: [])")
    }

    func testSingleKeyBaggageDescription() {
        var baggage = BaggageContext()
        baggage.testID = 42

        XCTAssertEqual(String(describing: baggage), #"BaggageContext(keys: ["TestIDKey"])"#)
    }

    func testMultiKeysBaggageDescription() {
        var baggage = BaggageContext()
        baggage.testID = 42
        baggage[SecondTestIDKey.self] = "test"

        let description = String(describing: baggage)
        XCTAssert(description.starts(with: "BaggageContext(keys: ["))
        // use contains instead of `XCTAssertEqual` because the order is non-predictable (Dictionary)
        XCTAssert(description.contains("TestIDKey"))
        XCTAssert(description.contains("ExplicitKeyName"))
        print(description.reversed().starts(with: "])"))
    }
}

private enum TestIDKey: BaggageContextKey {
    typealias Value = Int
}

private extension BaggageContext {
    var testID: Int? {
        get {
            self[TestIDKey.self]
        } set {
            self[TestIDKey.self] = newValue
        }
    }
}

private enum SecondTestIDKey: BaggageContextKey {
    typealias Value = String

    static let name: String? = "ExplicitKeyName"
}
