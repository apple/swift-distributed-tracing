//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020 Moritz Lang and the Swift Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Baggage
import Instrumentation
import XCTest

final class SpanTests: XCTestCase {
    func testAddingEventCreatesCopy() {
        // TODO: We should probably replace OTSpan at some point with a NoOpSpan for testing things like this.
        let span = OTSpan(
            operationName: "test",
            startTimestamp: .now(),
            context: BaggageContext(),
            kind: .internal,
            onEnd: { _ in }
        )
        XCTAssert(span.events.isEmpty)

        let copiedSpan = span.addingEvent("test-event")
        XCTAssertEqual(copiedSpan.events[0].name, "test-event")

        XCTAssert(span.events.isEmpty)
    }

    func testSpanEventIsExpressibleByStringLiteral() {
        let event: SpanEvent = "test"

        XCTAssertEqual(event.name, "test")
    }

    func testSpanAttributeIsExpressibleByStringLiteral() {
        let stringAttribute: SpanAttribute = "test"
        guard case .string(let stringValue) = stringAttribute else {
            XCTFail("Expected string attribute, got \(stringAttribute).")
            return
        }
        XCTAssertEqual(stringValue, "test")
    }

    func testSpanAttributeIsExpressibleByIntegerLiteral() {
        let intAttribute: SpanAttribute = 42
        guard case .int(let intValue) = intAttribute else {
            XCTFail("Expected int attribute, got \(intAttribute).")
            return
        }
        XCTAssertEqual(intValue, 42)
    }

    func testSpanAttributeIsExpressibleByFloatLiteral() {
        let doubleAttribute: SpanAttribute = 42.0
        guard case .double(let doubleValue) = doubleAttribute else {
            XCTFail("Expected float attribute, got \(doubleAttribute).")
            return
        }
        XCTAssertEqual(doubleValue, 42.0)
    }

    func testSpanAttributeIsExpressibleByBooleanLiteral() {
        let boolAttribute: SpanAttribute = false
        guard case .bool(let boolValue) = boolAttribute else {
            XCTFail("Expected bool attribute, got \(boolAttribute).")
            return
        }
        XCTAssertFalse(boolValue)
    }

    func testSpanAttributeIsExpressibleByArrayLiteral() {
        let attributes: SpanAttribute = [true, "test"]
        guard case .array(let arrayValue) = attributes else {
            XCTFail("Expected array attribute, got \(attributes).")
            return
        }

        guard case .bool(let boolValue) = arrayValue[0] else {
            XCTFail("Expected bool attribute, got \(arrayValue[0])")
            return
        }
        XCTAssert(boolValue)

        guard case .string(let stringValue) = arrayValue[1] else {
            XCTFail("Expected string attribute, got \(arrayValue[1])")
            return
        }
        XCTAssertEqual(stringValue, "test")
    }

    func testSpanAttributesProvideSubscriptAccess() {
        var attributes: SpanAttributes = [:]
        XCTAssert(attributes.isEmpty)

        attributes["0"] = false
        XCTAssertFalse(attributes.isEmpty)

        guard case .bool(let flag) = attributes["0"], !flag else {
            XCTFail("Expected subscript getter to return the bool attribute.")
            return
        }
    }

    func testSpanAttributesAreIteratable() {
        let attributes: SpanAttributes = ["0": 0, "1": true, "2": "test"]

        var dictionary = [String: SpanAttribute]()
        attributes.forEach { name, attribute in
            dictionary[name] = attribute
        }

        guard case .int = dictionary["0"], case .bool = dictionary["1"], case .string = dictionary["2"] else {
            XCTFail("Expected all attributes to be copied to the dictionary.")
            return
        }
    }
}
