//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift Distributed Tracing project
// authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_exported import InstrumentationBaggage

/// A `Span` represents an interval from the start of an operation to its end, along with additional metadata included
/// with it. A `Span` can be created from a `Baggage` or `LoggingContext` which MAY contain existing span identifiers,
/// in which case this span should be considered as "child" of the previous span.
///
/// Creating a `Span` is delegated to a ``Tracer`` and end users should never create them directly.
///
/// ### Reference semantics
/// A `Span` always exhibits reference semantics. Even if a span were to be implemented using a struct (or enum),
/// it must exhibit reference semantics. In other words, passing around a `Span` object and mutating it from multiple
/// places must mutate the same underlying storage, and must do so safely (i.e. take locks or use other synchronization
/// mechanisms to protect the mutations). This is because conceptually a span is not a value, and refers to a specific
/// resource that must be started, accumulate all possible information from the span's duration, and ended exactly once.
///
/// - SeeAlso: For more details refer to the [OpenTelemetry Specification: Span](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/api.md#span) which this type is compatible with.
public protocol Span: _SwiftTracingSendableSpan {
    /// The read-only `Baggage` of this `Span`, set when starting this `Span`.
    var baggage: Baggage { get }

    /// Returns the name of the operation this span represents.
    ///
    /// The name may be changed during the lifetime of a `Span`, this change
    /// may or may not impact the sampling decision and actually emitting the span,
    /// depending on how a backend decides to treat renames.
    ///
    /// This can still be useful when, for example, we want to immediately start
    /// span when receiving a request but make it more precise as handling of the request proceeds.
    /// For example, we can start a span immediately when a request is received in a server,
    /// and update it to reflect the matched route, if it did match one:
    ///
    /// - 1) Start span with basic path (e.g. `operationName = request.head.uri` during `withSpan`)
    ///   - 2.1) "Route Not Found" -> Record error
    ///   - 2.2) "Route Found" -> Rename to route (`/users/1` becomes `/users/:userID`)
    /// - 3) End span
    var operationName: String {
        get
        nonmutating set
    }

    /// Set the status.
    ///
    /// - Parameter status: The status of this `Span`.
    func setStatus(_ status: SpanStatus)

    /// Add a ``SpanEvent`` in place.
    ///
    /// - Parameter event: The ``SpanEvent`` to add to this `Span`.
    func addEvent(_ event: SpanEvent)

    /// Record an error of the given type described by the the given message.
    ///
    /// - Parameters:
    ///   - error: The error to be recorded.
    ///   - attributes: Additional attributes describing the error.
    func recordError(_ error: Error, attributes: SpanAttributes)

    /// The attributes describing this `Span`.
    var attributes: SpanAttributes {
        get
        nonmutating set
    }

    /// Returns true if this `Span` is recording information like events, attributes, status, etc.
    var isRecording: Bool { get }

    /// Add a ``SpanLink`` in place.
    ///
    /// - Parameter link: The `SpanLink` to add to this `Span`.
    func addLink(_ link: SpanLink)

    /// End this `Span` at the given time.
    ///
    /// ### Rules about ending Spans
    /// A Span must be ended only ONCE. Ending a Span multiple times or never at all is considered a programming error.
    ///
    /// A tracer implementation MAY decide to crash the application if e.g. running in debug mode and noticing such misuse.
    ///
    /// Implementations SHOULD prevent double-emitting by marking a span as ended internally, however it still is a
    /// programming mistake to rely on this behavior.
    ///
    /// Parameters:
    ///   - clock: The clock to use as time source for the start time of the ``Span``
    ///
    /// - SeeAlso: `Span.end()` which automatically uses the "current" time.
    func end<Clock: TracerClock>(clock: Clock)
}

extension Span {
    /// End this `Span` at the current time.
    ///
    /// ### Rules about ending Spans
    /// A Span must be ended only ONCE. Ending a Span multiple times or never at all is considered a programming error.
    ///
    /// A tracer implementation MAY decide to crash the application if e.g. running in debug mode and noticing such misuse.
    ///
    /// Implementations SHOULD prevent double-emitting by marking a span as ended internally, however it still is a
    /// programming mistake to rely on this behavior.
    ///
    /// - SeeAlso: ``end(clock:)`` which allows passing in a specific time, e.g. if the operation was ended and recorded somewhere and we need to post-factum record it.
    ///   Generally though prefer using the ``end()`` version of this API in user code and structure your system such that it can be called in the right place and time.
    public func end() {
        self.end(clock: DefaultTracerClock())
    }

    /// Adds a ``SpanLink`` between this `Span` and the given `Span`.
    ///
    /// - Parameter other: The `Span` to link to.
    /// - Parameter attributes: The ``SpanAttributes`` describing this link. Defaults to no attributes.
    public func addLink(_ other: Self, attributes: SpanAttributes = [:]) {
        self.addLink(SpanLink(baggage: other.baggage, attributes: attributes))
    }
}

extension Span {
    /// Record a failure described by the given error.
    ///
    /// - Parameters:
    ///   - error: The error to be recorded.
    public func recordError(_ error: Error) {
        self.recordError(error, attributes: [:])
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Span Event

/// An event that occurred during a ``Span``.
public struct SpanEvent: Equatable {
    /// The human-readable name of this `SpanEvent`.
    public let name: String

    /// One or more ``SpanAttribute``s with the same restrictions as defined for ``Span`` attributes.
    public var attributes: SpanAttributes

    /// The timestamp at which this event occurred.
    ///
    /// It should be expressed as the number of milliseconds since UNIX Epoch (January 1st 1970).
    public let millisecondsSinceEpoch: UInt64

    /// Create a new `SpanEvent`.
    /// - Parameters:
    ///   - name: The human-readable name of this event.
    ///   - attributes: attributes describing this event. Defaults to no attributes.
    ///   - clock: The clock to use as time source for the start time of the ``Span``
    public init<Clock: TracerClock>(name: String,
                                    clock: Clock,
                                    attributes: SpanAttributes = [:])
    {
        self.name = name
        self.attributes = attributes
        self.millisecondsSinceEpoch = clock.now.millisecondsSinceEpoch
    }

    public init(name: String,
                attributes: SpanAttributes = [:])
    {
        self.name = name
        self.attributes = attributes
        self.millisecondsSinceEpoch = DefaultTracerClock.now.millisecondsSinceEpoch
    }
}

extension SpanEvent: ExpressibleByStringLiteral {
    public init(stringLiteral name: String) {
        self.init(name: name)
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Span Attribute

public struct SpanAttributeKey<T>: Hashable, ExpressibleByStringLiteral where T: SpanAttributeConvertible {
    public let name: String

    public init(name: String) {
        self.name = name
    }

    public init(stringLiteral value: StringLiteralType) {
        self.name = value
    }
}

@dynamicMemberLookup
public protocol SpanAttributeNamespace {
    /// Type that contains the nested attributes, e.g. HTTPAttributes which would contain `statusCode` and similar vars.
    associatedtype NestedSpanAttributes: NestedSpanAttributesProtocol

    var attributes: SpanAttributes { get set }

    subscript<T>(dynamicMember dynamicMember: KeyPath<NestedSpanAttributes, SpanAttributeKey<T>>) -> T? where T: SpanAttributeConvertible {
        get
        set
    }

    subscript<Namespace>(dynamicMember dynamicMember: KeyPath<SpanAttribute, Namespace>) -> Namespace
        where Namespace: SpanAttributeNamespace
    {
        get
    }
}

public protocol NestedSpanAttributesProtocol {
    init()

    /// :nodoc: INTERNAL API
    /// Magic value allowing the dynamicMember lookup inside SpanAttributeNamespaces to work.
    ///
    /// There is no need of ever implementing this function explicitly, the default implementation is good enough.
    static var __namespace: Self { get }
}

extension NestedSpanAttributesProtocol {
    public static var __namespace: Self {
        .init()
    }
}

extension NestedSpanAttributesProtocol {
    public typealias Key = SpanAttributeKey
}

extension SpanAttributeNamespace {
    public subscript<T>(dynamicMember dynamicMember: KeyPath<NestedSpanAttributes, SpanAttributeKey<T>>) -> T?
        where T: SpanAttributeConvertible
    {
        get {
            let key = NestedSpanAttributes.__namespace[keyPath: dynamicMember]
            let spanAttribute = self.attributes[key.name]?.toSpanAttribute()
            switch spanAttribute {
            case .int32(let value):
                if T.self == Int.self {
                    return (Int(exactly: value) as! T)
                } else {
                    return value as? T
                }
            case .int64(let value):
                if T.self == Int.self {
                    return (Int(exactly: value) as! T)
                } else {
                    return value as? T
                }
            default:
                if let value = spanAttribute?.anyValue {
                    return value as? T
                } else {
                    return nil
                }
            }
        }
        set {
            let key = NestedSpanAttributes.__namespace[keyPath: dynamicMember]
            self.attributes[key.name] = newValue?.toSpanAttribute()
        }
    }

    public subscript<Namespace>(dynamicMember dynamicMember: KeyPath<SpanAttribute, Namespace>) -> Namespace
        where Namespace: SpanAttributeNamespace
    {
        SpanAttribute.int(0)[keyPath: dynamicMember]
    }
}

/// The value of an attribute used to describe a ``Span`` or ``SpanEvent``.
///
/// Arrays are allowed but are enforced to be homogenous.
///
/// Attributes cannot be "nested" their structure is a flat key/value representation.
public enum SpanAttribute: Equatable {
    public typealias Key = SpanAttributeKey

    case int32(Int32)
    case int64(Int64)

    case int32Array([Int32])
    case int64Array([Int64])

    case double(Double)
    case doubleArray([Double])

    case bool(Bool)
    case boolArray([Bool])

    case string(String)
    case stringArray([String])

    case __DO_NOT_SWITCH_EXHAUSTIVELY_OVER_THIS_ENUM

    case stringConvertible(CustomStringConvertible & Sendable)
    case stringConvertibleArray([CustomStringConvertible & Sendable])

    public static func int(_ value: Int64) -> SpanAttribute {
        .int64(value)
    }

    /// This is a "magic value" that is used to enable the KeyPath based accessors to specific attributes.
    internal static var _namespace: SpanAttribute {
        .int(0)
    }

    internal var anyValue: Any {
        switch self {
        case .int32(let value):
            return value
        case .int64(let value):
            return value
        case .int32Array(let value):
            return value
        case .int64Array(let value):
            return value
        case .double(let value):
            return value
        case .doubleArray(let value):
            return value
        case .bool(let value):
            return value
        case .boolArray(let value):
            return value
        case .string(let value):
            return value
        case .stringArray(let value):
            return value
        case .stringConvertible(let value):
            return value
        case .stringConvertibleArray(let value):
            return value
        case .__DO_NOT_SWITCH_EXHAUSTIVELY_OVER_THIS_ENUM:
            fatalError("Cannot have values of __DO_NOT_SWITCH_EXHAUSTIVELY_OVER_THIS_ENUM")
        }
    }

    public static func == (lhs: SpanAttribute, rhs: SpanAttribute) -> Bool {
        switch (lhs, rhs) {
        case (.int32(let l), .int32(let r)): return l == r
        case (.int64(let l), .int64(let r)): return l == r
        case (.int32Array(let l), .int32Array(let r)): return l == r
        case (.int64Array(let l), .int64Array(let r)): return l == r
        case (.double(let l), .double(let r)): return l == r
        case (.doubleArray(let l), .doubleArray(let r)): return l == r
        case (.bool(let l), .bool(let r)): return l == r
        case (.boolArray(let l), .boolArray(let r)): return l == r
        case (.string(let l), .string(let r)): return l == r
        case (.stringArray(let l), .stringArray(let r)): return l == r
        case (.stringConvertible(let l), .stringConvertible(let r)): return "\(l)" == "\(r)"
        case (.stringConvertibleArray(let l), .stringConvertibleArray(let r)): return "\(l)" == "\(r)"
        default:
            return false
        }
    }
}

extension SpanAttribute: SpanAttributeConvertible {
    public func toSpanAttribute() -> SpanAttribute {
        self
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Attribute Values

public protocol SpanAttributeConvertible {
    func toSpanAttribute() -> SpanAttribute
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Attribute Values: Arrays

extension Array where Element == Int {
    public func toSpanAttribute() -> SpanAttribute {
        if MemoryLayout<Int>.stride == 8 {
            return .int64Array(self.map(Int64.init))
        } else if MemoryLayout<Int>.stride == 4 {
            return .int32Array(self.map(Int32.init))
        } else {
            fatalError("Not supported Int width: \(MemoryLayout<Int>.stride)")
        }
    }
}

extension Array where Element == Int64 {
    public func toSpanAttribute() -> SpanAttribute {
        .int64Array(self)
    }
}

extension Array where Element == Double {
    public func toSpanAttribute() -> SpanAttribute {
        .doubleArray(self)
    }
}

// fallback implementation
extension Array: SpanAttributeConvertible where Element: SpanAttributeConvertible {
    public func toSpanAttribute() -> SpanAttribute {
        if let value = self as? [Int32] {
            return .int32Array(value)
        } else if let value = self as? [Int64] {
            return .int64Array(value)
        } else if let value = self as? [Double] {
            return .doubleArray(value)
        } else if let value = self as? [Bool] {
            return .boolArray(value)
        } else if let value = self as? [String] {
            return .stringArray(value)
        } else if let value = self as? [CustomStringConvertible & Sendable] {
            return .stringConvertibleArray(value)
        }
        fatalError("Not supported SpanAttribute array type: \(type(of: self))")
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Attribute Values: String

extension String: SpanAttributeConvertible {
    public func toSpanAttribute() -> SpanAttribute {
        .string(self)
    }
}

extension SpanAttribute: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension SpanAttribute: ExpressibleByStringInterpolation {
    public init(stringInterpolation value: SpanAttribute.StringInterpolation) {
        self = .string("\(value)")
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Attribute Values: Int

extension SpanAttribute: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(Int64(value))
    }
}

extension Int: SpanAttributeConvertible {
    public func toSpanAttribute() -> SpanAttribute {
        if MemoryLayout<Int>.stride == 8 {
            return .int64(Int64(self))
        } else if MemoryLayout<Int>.stride == 4 {
            return .int32(Int32(exactly: self)!)
        } else {
            fatalError("Not supported int width: \(MemoryLayout<Int>.stride)")
        }
    }
}

extension Int64: SpanAttributeConvertible {
    public func toSpanAttribute() -> SpanAttribute {
        .int64(self)
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Attribute Values: Float/Double

extension Float: SpanAttributeConvertible {
    public func toSpanAttribute() -> SpanAttribute {
        .double(Double(self))
    }
}

extension Double: SpanAttributeConvertible {
    public func toSpanAttribute() -> SpanAttribute {
        .double(self)
    }
}

extension SpanAttribute: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Attribute Values: Bool

extension Bool: SpanAttributeConvertible {
    public func toSpanAttribute() -> SpanAttribute {
        .bool(self)
    }
}

extension SpanAttribute: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: SpanAttributes: Namespaces

/// A container of ``SpanAttribute``s.
@dynamicMemberLookup
public struct SpanAttributes: Equatable {
    private var _attributes = [String: SpanAttribute]()
}

extension SpanAttributes {
    /// Create a set of attributes by wrapping the given dictionary.
    ///
    /// - Parameter attributes: The attributes dictionary to wrap.
    public init(_ attributes: [String: SpanAttribute]) {
        self._attributes = attributes
    }

    /// Accesses the ``SpanAttribute`` with the given name for reading and writing.
    ///
    /// Please be cautious to not abuse this APIs power to read attributes to "smuggle" values between calls.
    /// Only `Baggage` is intended to carry information in a readable fashion between functions / processes / nodes.
    /// The API does allow reading in order to support the subscript-based dynamic member lookup implementation of
    /// attributes which allows accessing them as `span.attributes.http.statusCode`, forcing us to expose a get operation on the attributes,
    /// due to the lack of set-only subscripts.
    ///
    /// - Parameter name: The name of the attribute used to identify the attribute.
    /// - Returns: The `SpanAttribute` identified by the given name, or `nil` if it's not present.
    public subscript(_ name: String) -> SpanAttributeConvertible? {
        get {
            self._attributes[name]
        }
        set {
            self._attributes[name] = newValue?.toSpanAttribute()
        }
    }

    /// Similar to `subscript(_:)` however returns the stored `SpanAttribute` rather than going through `SpanAttributeConvertible`.
    public func get(_ name: String) -> SpanAttribute? {
        self._attributes[name]
    }

    /// Similar to `subscript(_:)` however accepts a `SpanAttribute` rather than going through `SpanAttributeConvertible`.
    public mutating func set(_ name: String, value: SpanAttribute?) {
        self._attributes[name] = value
    }

    /// - Parameter callback: The function to call for each attribute.
    public func forEach(_ callback: (String, SpanAttribute) -> Void) {
        self._attributes.forEach {
            callback($0.key, $0.1)
        }
    }

    /// Merges the given `SpanAttributes` into these `SpanAttributes` by overwriting values of duplicate keys with those of the
    /// `other` attributes.
    ///
    /// - Parameter other: `SpanAttributes` to merge.
    public mutating func merge(_ other: SpanAttributes) {
        self._attributes.merge(other._attributes, uniquingKeysWith: { _, rhs in rhs })
    }

    /// - Returns: Number of attributes stored.
    public var count: Int {
        self._attributes.count
    }

    /// Returns true if the collection contains no attributes.
    public var isEmpty: Bool {
        self._attributes.isEmpty
    }
}

#if swift(>=5.2)
extension SpanAttributes {
    /// Enables for type-safe fluent accessors for attributes.
    public subscript<T>(dynamicMember dynamicMember: KeyPath<SpanAttribute, SpanAttributeKey<T>>) -> SpanAttribute? {
        get {
            let key = SpanAttribute._namespace[keyPath: dynamicMember]
            return self._attributes[key.name]
        }
        set {
            let key = SpanAttribute._namespace[keyPath: dynamicMember]
            self._attributes[key.name] = newValue
        }
    }

    /// Enables for type-safe nested namespaces for attribute accessors.
    public subscript<Namespace>(dynamicMember dynamicMember: KeyPath<SpanAttribute, Namespace>) -> Namespace
        where Namespace: SpanAttributeNamespace
    {
        SpanAttribute._namespace[keyPath: dynamicMember]
    }
}
#endif

extension SpanAttributes: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, SpanAttribute)...) {
        self._attributes = [String: SpanAttribute](uniqueKeysWithValues: elements)
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Span Status

/// Represents the status of a finished Span. It's composed of a status code in conjunction with an optional descriptive message.
public struct SpanStatus: Equatable {
    public let code: Code
    public let message: String?

    /// Create a new `SpanStatus`.
    ///
    /// - Parameters:
    ///   - code: The ``SpanStatus/Code-swift.enum`` of this `SpanStatus`.
    ///   - message: The optional descriptive message of this `SpanStatus`. Defaults to nil.
    public init(code: Code, message: String? = nil) {
        self.code = code
        self.message = message
    }

    /// A code representing the status of a ``Span``.
    ///
    /// - SeeAlso: For the semantics of status codes see [OpenTelemetry Specification: setStatus](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/api.md#set-status)
    public enum Code {
        /// The Span has been validated by an Application developer or Operator to have completed successfully.
        case ok
        /// The Span contains an error.
        case error
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Span Kind

/// Describes the relationship between the ``Span``, its parents, and its children in a Trace.
public enum SpanKind {
    /// Indicates that the span covers server-side handling of a synchronous RPC or other remote request.
    /// This span is the child of a remote `.client` span that was expected to wait for a response.
    case server
    /// Indicates that the span describes a synchronous request to some remote service.
    /// This span is the parent of a remote `.server` span and waits for its response.
    case client
    /// Indicates that the span describes the parent of an asynchronous request. This parent span is expected to end before the corresponding child
    /// `.consumer` span, possibly even before the child span starts. In messaging scenarios with batching,
    /// tracing individual messages requires a new `.producer` span per message to be created.
    case producer
    /// Indicates that the span describes the child of an asynchronous `.producer` request.
    case consumer
    /// Indicates that the span represents an internal operation within an application, as opposed to an operations with remote parents or children.
    case `internal`
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Span Link

/// A link to another ``Span``.
/// The other ``Span``s information is stored in `context` and `attributes` may be used to
/// further describe the link.
public struct SpanLink {
    /// A `Baggage` containing identifying information about the link target ``Span``.
    public let baggage: Baggage

    /// ``SpanAttributes`` further describing the connection between the ``Span``s.
    public let attributes: SpanAttributes

    /// Create a new `SpanLink`.
    ///
    /// - Parameters:
    ///   - baggage: The `Baggage` identifying the targeted ``Span``.
    ///   - attributes: ``SpanAttributes`` that further describe the link. Defaults to no attributes.
    public init(baggage: Baggage, attributes: SpanAttributes) {
        self.baggage = baggage
        self.attributes = attributes
    }
}

@preconcurrency public protocol _SwiftTracingSendableSpan: Sendable {}

extension SpanAttributes: Sendable {}
extension SpanAttribute: Sendable {} // @unchecked because some payloads are CustomStringConvertible
extension SpanStatus: Sendable {}
extension SpanEvent: Sendable {}
extension SpanKind: Sendable {}
extension SpanStatus.Code: Sendable {}
extension SpanLink: Sendable {}
