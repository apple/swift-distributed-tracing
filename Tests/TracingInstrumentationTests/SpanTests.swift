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
import TracingInstrumentation
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

    func testSpanAttributeIsExpressibleByStringInterpolation() {
        let stringAttribute: SpanAttribute = "test \(true) \(42) \(3.14)"
        guard case .string(let stringValue) = stringAttribute else {
            XCTFail("Expected string attribute, got \(stringAttribute).")
            return
        }
        XCTAssertEqual(stringValue, "test true 42 3.14")
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

//    func testSpanAttributesProvideSubscriptAccess() {
//        var attributes: SpanAttributes = [:]
//        XCTAssert(attributes.isEmpty)
//
//        attributes["0"] = false
//        XCTAssertFalse(attributes.isEmpty)
//
//        guard case .bool(let flag) = attributes["0"], !flag else {
//            XCTFail("Expected subscript getter to return the bool attribute.")
//            return
//        }
//    }

    func testSpanAttributesUX() {
        var attributes: SpanAttributes = [:]

        // normally we can use just the span attribute values, and it is not type safe or guided in any way:
        attributes["thing.name"] = "hello"
        attributes["meaning.of.life"] = 42
        attributes["integers"] = [1, 2, 3, 4]
        attributes["names"] = ["alpha", "beta"]
        attributes["bools"] = [true, false, true]
        attributes["alive"] = false

        XCTAssertEqual(attributes["thing.name"], SpanAttribute.string("hello"))
        XCTAssertEqual(attributes["meaning.of.life"], SpanAttribute.int(42))
        XCTAssertEqual(attributes["alive"], SpanAttribute.bool(false))

        // An import like: `import OpenTelemetryInstrumentationSupport` can enable type-safe well defined attributes,
        // e.g. as defined in https://github.com/open-telemetry/opentelemetry-specification/tree/master/specification/trace/semantic_conventions
        attributes.name = "kappa"
        attributes.sampleHttp.statusCode = 200
        attributes.sampleHttp.codesArray = [1, 2, 3]

        XCTAssertEqual(attributes.name, SpanAttribute.string("kappa"))
        XCTAssertEqual(attributes.name, "kappa")
        XCTAssertEqual(attributes.sampleHttp.statusCode, 200)
    }

    func testSpanAttributesCustomValue() {
        var attributes: SpanAttributes = [:]

        // normally we can use just the span attribute values, and it is not type safe or guided in any way:
        attributes.sampleHttp.customType = CustomAttributeValue()

        XCTAssertEqual(attributes["http.custom_value"], SpanAttribute.stringConvertible(CustomAttributeValue()))
        XCTAssertEqual(String(reflecting: attributes.sampleHttp.customType), "Optional(CustomAttributeValue())")
        XCTAssertEqual(attributes.sampleHttp.customType, CustomAttributeValue())
    }

    func testSpanAttributesAreIterable() {
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

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Example Span attributes

extension SpanAttribute {
    var name: SpanAttributeKey<String> {
        "name"
    }
}

extension SpanAttributes {
    public var sampleHttp: HTTPAttributes {
        get {
            .init(attributes: self)
        }
        set {
            self = newValue.attributes
        }
    }
}

@dynamicMemberLookup
public struct HTTPAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes
    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    public struct NestedAttributes: NestedSpanAttributesProtocol {
        public init() {}

        public var statusCode: SpanAttributeKey<Int> {
            "http.status_code"
        }

        public var codesArray: SpanAttributeKey<[Int]> {
            "http.codes_array"
        }

        public var customType: SpanAttributeKey<CustomAttributeValue> {
            "http.custom_value"
        }
    }
}

public struct CustomAttributeValue: Equatable, CustomStringConvertible, SpanAttributeConvertible {
    public func toSpanAttribute() -> SpanAttribute {
        .stringConvertible(self)
    }

    public var description: String {
        "CustomAttributeValue()"
    }
}
