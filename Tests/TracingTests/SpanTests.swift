//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2021 Apple Inc. and the Swift Distributed Tracing project
// authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Instrumentation
import InstrumentationBaggage
import Tracing
import XCTest

final class SpanTests: XCTestCase {
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
        let s = InstrumentationSystem.tracer.startSpan("", baggage: .topLevel)
        s.attributes["hi"] = [42, 21]
        s.attributes["hi"] = [42.10, 21.0]
        s.attributes["hi"] = [true, false]
        s.attributes["hi"] = ["one", "two"]
        s.attributes["hi"] = [1, 2, 34]
    }

    func testSpanAttributesUX() {
        var attributes: SpanAttributes = [:]

        // normally we can use just the span attribute values, and it is not type safe or guided in any way:
        attributes["thing.name"] = "hello"
        attributes["meaning.of.life"] = 42
        attributes["integers"] = [1, 2, 3, 4]
        attributes["names"] = ["alpha", "beta"]
        attributes["bools"] = [true, false, true]
        attributes["alive"] = false

        XCTAssertEqual(attributes["thing.name"]?.toSpanAttribute(), SpanAttribute.string("hello"))
        XCTAssertEqual(attributes["meaning.of.life"]?.toSpanAttribute(), SpanAttribute.int(42))
        XCTAssertEqual(attributes["alive"]?.toSpanAttribute(), SpanAttribute.bool(false))

        // using swift 5.2, we can improve upon that by using type-safe, keypath-based subscripts:
        #if swift(>=5.2)
        // An import like: `import TracingOpenTelemetrySupport` can enable type-safe well defined attributes,
        // e.g. as defined in https://github.com/open-telemetry/opentelemetry-specification/tree/master/specification/trace/semantic_conventions
        attributes.name = "kappa"
        attributes.sampleHttp.statusCode = 200
        attributes.sampleHttp.codesArray = [1, 2, 3]

        XCTAssertEqual(attributes.name, SpanAttribute.string("kappa"))
        XCTAssertEqual(attributes.name, "kappa")
        XCTAssertEqual(attributes.sampleHttp.statusCode, 200)
        #endif
    }

    func testSpanAttributesCustomValue() {
        #if swift(>=5.2)
        var attributes: SpanAttributes = [:]

        // normally we can use just the span attribute values, and it is not type safe or guided in any way:
        attributes.sampleHttp.customType = CustomAttributeValue()

        XCTAssertEqual(attributes["http.custom_value"]?.toSpanAttribute(), SpanAttribute.stringConvertible(CustomAttributeValue()))
        XCTAssertEqual(String(reflecting: attributes.sampleHttp.customType), "Optional(CustomAttributeValue())")
        XCTAssertEqual(attributes.sampleHttp.customType, CustomAttributeValue())
        #endif
    }

    func testSpanAttributesAreIterable() {
        let attributes: SpanAttributes = [
            "0": 0,
            "1": true,
            "2": "test",
        ]

        var dictionary = [String: SpanAttribute]()
        attributes.forEach { name, attribute in
            dictionary[name] = attribute
        }

        guard case .some(.int) = dictionary["0"], case .some(.bool) = dictionary["1"], case .some(.string) = dictionary["2"] else {
            XCTFail("Expected all attributes to be copied to the dictionary.")
            return
        }
    }

    func testSpanAttributesMerge() {
        var attributes: SpanAttributes = [
            "0": 0,
            "1": true,
            "2": "test",
        ]
        let other: SpanAttributes = [
            "0": 1,
            "1": false,
            "3": "new",
        ]

        attributes.merge(other)

        XCTAssertEqual(attributes["0"]?.toSpanAttribute(), 1)
        XCTAssertEqual(attributes["1"]?.toSpanAttribute(), false)
        XCTAssertEqual(attributes["2"]?.toSpanAttribute(), "test")
        XCTAssertEqual(attributes["3"]?.toSpanAttribute(), "new")
    }

    func testSpanParentConvenience() {
        var parentBaggage = Baggage.topLevel
        parentBaggage[TestBaggageContextKey.self] = "test"

        let parent = TestSpan(
            operationName: "client",
            startTime: .now(),
            baggage: parentBaggage,
            kind: .client,
            onEnd: { _ in }
        )
        let childBaggage = Baggage.topLevel
        let child = TestSpan(
            operationName: "server",
            startTime: .now(),
            baggage: childBaggage,
            kind: .server,
            onEnd: { _ in }
        )

        var attributes = SpanAttributes()
        #if swift(>=5.2)
        attributes.sampleHttp.statusCode = 418
        #else
        attributes["http.status_code"] = 418
        #endif
        child.addLink(parent, attributes: attributes)

        XCTAssertEqual(child.links.count, 1)
        XCTAssertEqual(child.links[0].baggage[TestBaggageContextKey.self], "test")
        #if swift(>=5.2)
        XCTAssertEqual(child.links[0].attributes.sampleHttp.statusCode, 418)
        #endif
        guard case .some(.int(let statusCode)) = child.links[0].attributes["http.status_code"]?.toSpanAttribute() else {
            XCTFail("Expected int value for http.status_code")
            return
        }
        XCTAssertEqual(statusCode, 418)
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Example Span attributes

extension SpanAttribute {
    var name: Key<String> {
        "name"
    }
}

#if swift(>=5.2)
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

    public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
        public init() {}

        public var statusCode: Key<Int> {
            "http.status_code"
        }

        public var codesArray: Key<[Int]> {
            "http.codes_array"
        }

        public var customType: Key<CustomAttributeValue> {
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
#endif

private struct TestBaggageContextKey: BaggageKey {
    typealias Value = String
}
