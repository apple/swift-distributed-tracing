import BaggageContext
import XCTest

final class BaggageContextTests: XCTestCase {
    func testSubscriptAccess() {
        let value = 42

        var baggage = BaggageContext()
        XCTAssertNil(baggage[TestContextKey.self])

        baggage[TestContextKey.self] = value
        XCTAssertEqual(baggage[TestContextKey], value)

        baggage[TestContextKey.self] = nil
        XCTAssertNil(baggage[TestContextKey.self])
    }
}

private enum TestContextKey: BaggageContextKey {
    typealias Value = Int
}
