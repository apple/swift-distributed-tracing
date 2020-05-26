import ContextPropagation
import XCTest

final class ContextTests: XCTestCase {
    func testMutations() {
        let traceID = UUID()
        var context = Context()
        XCTAssertNil(context.extract(TestTraceIDKey.self))

        context.inject(TestTraceIDKey.self, value: traceID)
        XCTAssertEqual(context.extract(TestTraceIDKey.self), traceID)

        context.remove(TestTraceIDKey.self)
        XCTAssertNil(context.extract(TestTraceIDKey.self))
    }
}

private enum TestTraceIDKey: ContextKey {
    typealias Value = UUID
}
