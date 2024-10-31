//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ServiceContextModule
import Tracing
import XCTest

@testable import Instrumentation

final class SpanTests: XCTestCase {
    func testSpanEventIsExpressibleByStringLiteral() {
        let event: SpanEvent = "test"

        XCTAssertEqual(event.name, "test")
    }

    func testSpanEventUsesNanosecondsFromClock() {
        let clock = MockClock()
        clock.setTime(42_000_000)

        let event = SpanEvent(name: "test", at: clock.now)

        XCTAssertEqual(event.name, "test")
        XCTAssertEqual(event.nanosecondsSinceEpoch, 42_000_000)
        XCTAssertEqual(event.millisecondsSinceEpoch, 42)
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
        guard case .int64(let intValue) = intAttribute else {
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
        let s = InstrumentationSystem.legacyTracer.startAnySpan("", context: .topLevel)
        s.attributes["hi"] = [42, 21]
        s.attributes["hi"] = [42.10, 21.0]
        s.attributes["hi"] = [true, false]
        s.attributes["hi"] = ["one", "two"]
        s.attributes["hi"] = [1, 2, 34]
    }

    func testSpanAttributeSetEntireCollection() {
        InstrumentationSystem.bootstrapInternal(TestTracer())
        defer {
            InstrumentationSystem.bootstrapInternal(NoOpTracer())
        }

        let s = InstrumentationSystem.legacyTracer.startAnySpan("", context: .topLevel)
        var attrs = s.attributes
        attrs["one"] = 42
        attrs["two"] = [1, 2, 34]
        s.attributes = attrs
        XCTAssertEqual(s.attributes["one"]?.toSpanAttribute(), SpanAttribute.int(42))
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

        // An import like: `import TracingOpenTelemetrySupport` can enable type-safe well defined attributes
        attributes.name = "kappa"
        attributes.sampleHttp.statusCode = 200
        attributes.sampleHttp.codesArray = [1, 2, 3]

        XCTAssertEqual(attributes.name, SpanAttribute.string("kappa"))
        XCTAssertEqual(attributes.name, "kappa")
        print("attributes", attributes)
        XCTAssertEqual(attributes.sampleHttp.statusCode, 200)
        XCTAssertEqual(attributes.sampleHttp.codesArray, [1, 2, 3])
    }

    func testSpanAttributesCustomValue() {
        var attributes: SpanAttributes = [:]

        // normally we can use just the span attribute values, and it is not type safe or guided in any way:
        attributes.sampleHttp.customType = CustomAttributeValue()

        XCTAssertEqual(
            attributes["http.custom_value"]?.toSpanAttribute(),
            SpanAttribute.stringConvertible(CustomAttributeValue())
        )
        XCTAssertEqual(String(reflecting: attributes.sampleHttp.customType), "Optional(CustomAttributeValue())")
        XCTAssertEqual(attributes.sampleHttp.customType, CustomAttributeValue())
    }

    func testSpanAttributesAreIterable() {
        let attributes: SpanAttributes = [
            "0": 0,
            "1": true,
            "2": "test",
        ]

        var dictionary = [String: SpanAttribute]()

        // swift-format-ignore: ReplaceForEachWithForLoop
        attributes.forEach { name, attribute in
            dictionary[name] = attribute
        }

        guard case .some(.int64) = dictionary["0"], case .some(.bool) = dictionary["1"],
            case .some(.string) = dictionary["2"]
        else {
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
        var parentBaggage = ServiceContext.topLevel
        parentBaggage[TestBaggageContextKey.self] = "test"

        let parent = TestSpan(
            operationName: "client",
            startTime: DefaultTracerClock.now,
            context: parentBaggage,
            kind: .client,
            onEnd: { _ in }
        )
        let childBaggage = ServiceContext.topLevel
        let child = TestSpan(
            operationName: "server",
            startTime: DefaultTracerClock.now,
            context: childBaggage,
            kind: .server,
            onEnd: { _ in }
        )

        var attributes = SpanAttributes()
        attributes.sampleHttp.statusCode = 418
        child.addLink(parent, attributes: attributes)

        XCTAssertEqual(child.links.count, 1)
        XCTAssertEqual(child.links[0].context[TestBaggageContextKey.self], "test")
        XCTAssertEqual(child.links[0].attributes.sampleHttp.statusCode, 418)
        guard case .some(.int64(let statusCode)) = child.links[0].attributes["http.status_code"]?.toSpanAttribute()
        else {
            XCTFail("Expected int value for http.status_code")
            return
        }
        XCTAssertEqual(statusCode, 418)
    }

    func testSpanAttributeSetterGetter() {
        var parentBaggage = ServiceContext.topLevel
        parentBaggage[TestBaggageContextKey.self] = "test"

        let parent = TestSpan(
            operationName: "client",
            startTime: DefaultTracerClock.now,
            context: parentBaggage,
            kind: .client,
            onEnd: { _ in }
        )
        let childBaggage = ServiceContext.topLevel
        let child = TestSpan(
            operationName: "server",
            startTime: DefaultTracerClock.now,
            context: childBaggage,
            kind: .server,
            onEnd: { _ in }
        )

        var attributes = SpanAttributes()
        attributes.set("http.status_code", value: .int32(418))
        child.addLink(parent, attributes: attributes)

        XCTAssertEqual(child.links.count, 1)
        XCTAssertEqual(child.links[0].context[TestBaggageContextKey.self], "test")
        XCTAssertEqual(child.links[0].attributes.sampleHttp.statusCode, 418)
        guard case .some(.int32(let statusCode)) = child.links[0].attributes["http.status_code"]?.toSpanAttribute()
        else {
            XCTFail("Expected int value for http.status_code")
            return
        }
        XCTAssertEqual(statusCode, 418)
        XCTAssertEqual(attributes.get("http.status_code"), SpanAttribute.int32(418))
    }

    func testSpanUpdateAttributes() {
        let span = TestSpan(
            operationName: "client",
            startTime: DefaultTracerClock.now,
            context: ServiceContext.topLevel,
            kind: .client,
            onEnd: { _ in }
        )
        span.updateAttributes { attributes in
            attributes.set("http.status_code", value: .int32(200))
            attributes.set("http.method", value: .string("GET"))
        }

        XCTAssertEqual(span.attributes.get("http.status_code"), .int32(200))
        XCTAssertEqual(span.attributes.get("http.method"), .string("GET"))
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Example Span attributes

extension SpanAttribute {
    var name: Key<String> {
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

public struct CustomAttributeValue: Equatable, Sendable, CustomStringConvertible, SpanAttributeConvertible {
    public func toSpanAttribute() -> SpanAttribute {
        .stringConvertible(self)
    }

    public var description: String {
        "CustomAttributeValue()"
    }
}

private struct TestBaggageContextKey: ServiceContextKey {
    typealias Value = String
}
