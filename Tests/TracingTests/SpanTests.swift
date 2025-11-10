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
import Testing
import Tracing

@testable import Instrumentation

@Suite("Span Tests")
struct SpanTests {
    @Test("SpanEvent is ExpressibleByStringLiteral")
    func spanEventIsExpressibleByStringLiteral() {
        let event: SpanEvent = "test"

        #expect(event.name == "test")
    }

    @Test("SpanEvent uses nanoseconds from clock")
    func spanEventUsesNanosecondsFromClock() {
        let clock = MockClock()
        clock.setTime(42_000_000)

        let event = SpanEvent(name: "test", at: clock.now)

        #expect(event.name == "test")
        #expect(event.nanosecondsSinceEpoch == 42_000_000)
        #expect(event.millisecondsSinceEpoch == 42)
    }

    @Test("SpanAttribute is ExpressibleByStringLiteral")
    func spanAttributeIsExpressibleByStringLiteral() {
        let stringAttribute: SpanAttribute = "test"
        guard case .string(let stringValue) = stringAttribute else {
            Issue.record("Expected string attribute, got \(stringAttribute).")
            return
        }
        #expect(stringValue == "test")
    }

    @Test("SpanAttribute is ExpressibleByStringInterpolation")
    func spanAttributeIsExpressibleByStringInterpolation() {
        let stringAttribute: SpanAttribute = "test \(true) \(42) \(3.14)"
        guard case .string(let stringValue) = stringAttribute else {
            Issue.record("Expected string attribute, got \(stringAttribute).")
            return
        }
        #expect(stringValue == "test true 42 3.14")
    }

    @Test("SpanAttribute is ExpressibleByIntegerLiteral")
    func spanAttributeIsExpressibleByIntegerLiteral() {
        let intAttribute: SpanAttribute = 42
        guard case .int64(let intValue) = intAttribute else {
            Issue.record("Expected int attribute, got \(intAttribute).")
            return
        }
        #expect(intValue == 42)
    }

    @Test("SpanAttribute is ExpressibleByFloatLiteral")
    func spanAttributeIsExpressibleByFloatLiteral() {
        let doubleAttribute: SpanAttribute = 42.0
        guard case .double(let doubleValue) = doubleAttribute else {
            Issue.record("Expected float attribute, got \(doubleAttribute).")
            return
        }
        #expect(doubleValue == 42.0)
    }

    @Test("SpanAttribute is ExpressibleByBooleanLiteral")
    func spanAttributeIsExpressibleByBooleanLiteral() {
        let boolAttribute: SpanAttribute = false
        guard case .bool(let boolValue) = boolAttribute else {
            Issue.record("Expected bool attribute, got \(boolAttribute).")
            return
        }
        #expect(boolValue == false)
    }

    @Test("SpanAttribute is ExpressibleByArrayLiteral")
    func spanAttributeIsExpressibleByArrayLiteral() {
        let tracer = TestTracer()
        let s = tracer.startAnySpan("", context: .topLevel)
        s.attributes["hi"] = [42, 21]
        s.attributes["hi"] = [42.10, 21.0]
        s.attributes["hi"] = [true, false]
        s.attributes["hi"] = ["one", "two"]
        s.attributes["hi"] = [1, 2, 34]
    }

    @Test("SpanAttribute set entire collection")
    func spanAttributeSetEntireCollection() {
        let tracer = TestTracer()
        let s = tracer.startAnySpan("", context: .topLevel)
        var attrs = s.attributes
        attrs["one"] = 42
        attrs["two"] = [1, 2, 34]
        s.attributes = attrs
        #expect(s.attributes["one"]?.toSpanAttribute() == SpanAttribute.int(42))
    }

    @Test("SpanAttributes UX")
    func spanAttributesUX() {
        var attributes: SpanAttributes = [:]

        // normally we can use just the span attribute values, and it is not type safe or guided in any way:
        attributes["thing.name"] = "hello"
        attributes["meaning.of.life"] = 42
        attributes["integers"] = [1, 2, 3, 4]
        attributes["names"] = ["alpha", "beta"]
        attributes["bools"] = [true, false, true]
        attributes["alive"] = false

        #expect(attributes["thing.name"]?.toSpanAttribute() == SpanAttribute.string("hello"))
        #expect(attributes["meaning.of.life"]?.toSpanAttribute() == SpanAttribute.int(42))
        #expect(attributes["alive"]?.toSpanAttribute() == SpanAttribute.bool(false))

        // An import like: `import TracingOpenTelemetrySupport` can enable type-safe well defined attributes
        attributes.name = "kappa"
        attributes.sampleHttp.statusCode = 200
        attributes.sampleHttp.codesArray = [1, 2, 3]

        #expect(attributes.name == SpanAttribute.string("kappa"))
        #expect(attributes.name == "kappa")
        print("attributes", attributes)
        #expect(attributes.sampleHttp.statusCode == 200)
        #expect(attributes.sampleHttp.codesArray == [1, 2, 3])
    }

    @Test("SpanAttributes custom value")
    func spanAttributesCustomValue() {
        var attributes: SpanAttributes = [:]

        // normally we can use just the span attribute values, and it is not type safe or guided in any way:
        attributes.sampleHttp.customType = CustomAttributeValue()

        #expect(
            attributes["http.custom_value"]?.toSpanAttribute()
                == SpanAttribute.stringConvertible(CustomAttributeValue())
        )
        #expect(String(reflecting: attributes.sampleHttp.customType) == "Optional(CustomAttributeValue())")
        #expect(attributes.sampleHttp.customType == CustomAttributeValue())
    }

    @Test("SpanAttributes are iterable")
    func spanAttributesAreIterable() {
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
            Issue.record("Expected all attributes to be copied to the dictionary.")
            return
        }
    }

    @Test("SpanAttributes merge")
    func spanAttributesMerge() {
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

        #expect(attributes["0"]?.toSpanAttribute() == 1)
        #expect(attributes["1"]?.toSpanAttribute() == false)
        #expect(attributes["2"]?.toSpanAttribute() == "test")
        #expect(attributes["3"]?.toSpanAttribute() == "new")
    }

    @Test("Span parent convenience")
    func spanParentConvenience() {
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

        #expect(child.links.count == 1)
        #expect(child.links[0].context[TestBaggageContextKey.self] == "test")
        #expect(child.links[0].attributes.sampleHttp.statusCode == 418)
        guard case .some(.int64(let statusCode)) = child.links[0].attributes["http.status_code"]?.toSpanAttribute()
        else {
            Issue.record("Expected int value for http.status_code")
            return
        }
        #expect(statusCode == 418)
    }

    @Test("SpanAttribute setter/getter")
    func spanAttributeSetterGetter() {
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

        #expect(child.links.count == 1)
        #expect(child.links[0].context[TestBaggageContextKey.self] == "test")
        #expect(child.links[0].attributes.sampleHttp.statusCode == 418)
        guard case .some(.int32(let statusCode)) = child.links[0].attributes["http.status_code"]?.toSpanAttribute()
        else {
            Issue.record("Expected int value for http.status_code")
            return
        }
        #expect(statusCode == 418)
        #expect(attributes.get("http.status_code") == SpanAttribute.int32(418))
    }

    @Test("Span update attributes")
    func spanUpdateAttributes() {
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

        #expect(span.attributes.get("http.status_code") == .int32(200))
        #expect(span.attributes.get("http.method") == .string("GET"))
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
    package var sampleHttp: HTTPAttributes {
        get {
            .init(attributes: self)
        }
        set {
            self = newValue.attributes
        }
    }
}

@dynamicMemberLookup
package struct HTTPAttributes: SpanAttributeNamespace {
    package var attributes: SpanAttributes
    package init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    package struct NestedSpanAttributes: NestedSpanAttributesProtocol {
        package init() {}

        package var statusCode: Key<Int> {
            "http.status_code"
        }

        package var codesArray: Key<[Int]> {
            "http.codes_array"
        }

        package var customType: Key<CustomAttributeValue> {
            "http.custom_value"
        }
    }
}

package struct CustomAttributeValue: Equatable, Sendable, CustomStringConvertible, SpanAttributeConvertible {
    package func toSpanAttribute() -> SpanAttribute {
        .stringConvertible(self)
    }

    package var description: String {
        "CustomAttributeValue()"
    }
}

private struct TestBaggageContextKey: ServiceContextKey {
    typealias Value = String
}
