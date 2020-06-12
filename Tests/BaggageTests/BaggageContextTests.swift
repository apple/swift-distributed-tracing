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
