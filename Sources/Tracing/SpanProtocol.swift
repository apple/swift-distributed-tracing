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

@_exported import ServiceContextModule

/// A span represents an interval from the start of an operation to its end, along with additional metadata included
/// with it.
///
/// A `Span` can be created from a `ServiceContext` or `LoggingContext` which MAY contain existing span identifiers,
/// in which case this span should be considered as child of the previous span.
///
/// Spans are created by invoking the `withSpan` method that delegates to the currently configured bootstrapped
/// tracer. By default tracers use the current task-local `ServiceContext` to perform this association.
///
/// ### Reference semantics
///
/// A `Span` always exhibits reference semantics. Even if a span were to be implemented using a struct (or enum),
/// it must exhibit reference semantics. In other words, passing around a `Span` object and mutating it from multiple
/// places must mutate the same underlying storage, and must do so safely (that is, take locks or use other synchronization
/// mechanisms to protect the mutations). This is because conceptually a span is not a value, and refers to a specific
/// resource that must be started, accumulate all possible information from the span's duration, and end exactly once.
///
/// - SeeAlso: For more details refer to the [OpenTelemetry Specification: Span](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/api.md#span) which this type is compatible with.
public protocol Span: Sendable {
    /// The read-only service context of this span, set when it starts.
    var context: ServiceContext { get }

    /// The name of the operation this span represents.
    ///
    /// The name may be changed during the lifetime of a `Span`. This change
    /// may or may not impact sampling decisions or emitting the span,
    /// depending on how a tracing backend handles renames.
    ///
    /// This can still be useful when, for example, you want to immediately start a
    /// span when you receive a request and make it more precise as the handling of the request proceeds.
    /// For example, you can start a span immediately when a request is received in a server,
    /// then update it to reflect the matched route, if it did match one:
    ///
    /// - 1) Start span with basic path (such as `operationName = request.head.uri` during `withSpan`)
    ///   - 2.1) "Route Not Found" -> Record error
    ///   - 2.2) "Route Found" -> Rename to route (`/users/1` becomes `/users/:userID`)
    /// - 3) End span
    var operationName: String {
        get
        nonmutating set
    }

    /// Set the status of the span.
    ///
    /// - Parameter status: The status of this `Span`.
    func setStatus(_ status: SpanStatus)

    /// Adds an event to this span.
    ///
    /// Span events (``SpanEvent``) are similar to log statements in logging systems, in the sense
    /// that they can carry a name of some event that has happened with an associated timestamp.
    ///
    /// Events can be used to complement a span with interesting point-in-time information.
    /// For example, if code executing a span has been cancelled it might be useful
    /// to emit an event representing this task cancellation, which then (presumably) leads
    /// to a quicker termination of the task.
    ///
    /// - Parameter event: The ``SpanEvent`` to add to this `Span`.
    func addEvent(_ event: SpanEvent)

    /// Record an error and attributes associated with the error into the span.
    ///
    /// - Parameters:
    ///   - error: The error to be recorded.
    ///   - attributes: Additional attributes that describe the error.
    ///   - instant: the time instant at which the event occurred.
    func recordError<Instant: TracerInstant>(
        _ error: Error,
        attributes: SpanAttributes,
        at instant: @autoclosure () -> Instant
    )

    /// The attributes that describe this span.
    var attributes: SpanAttributes {
        get
        nonmutating set
    }

    /// A Boolean value that indicates whether the span is recording information such as events, attributes, status, and so on.
    var isRecording: Bool { get }

    /// Add a link to the span.
    ///
    /// - Parameter link: The `SpanLink` to add to this `Span`.
    func addLink(_ link: SpanLink)

    /// End the span.
    ///
    /// ### Rules about ending Spans
    /// A Span must be ended only ONCE. Ending a Span multiple times or never at all is a programming error.
    ///
    /// A tracer implementation MAY decide to crash the application if, for example, running in debug mode and noticing such misuse.
    ///
    /// Implementations SHOULD prevent double-emitting by marking a span as ended internally, however it is a
    /// programming mistake to rely on this behavior.
    ///
    /// - Parameter instant: the time instant at which the span ended
    /// - SeeAlso: ``end()`` which automatically uses the current time.
    func end<Instant: TracerInstant>(at instant: @autoclosure () -> Instant)
}

extension Span {
    /// Record an error and attributes associated with the error into the span.
    ///
    /// - Parameters:
    ///   - error: The error to record.
    ///   - attributes: Additional attributes that describe the error.
    public func recordError(_ error: Error, attributes: SpanAttributes) {
        self.recordError(error, attributes: attributes, at: DefaultTracerClock.now)
    }

    /// End the span.
    ///
    /// ### Rules about ending Spans
    /// A Span must be ended only ONCE. Ending a Span multiple times or never at all is a programming error.
    ///
    /// A tracer implementation MAY decide to crash the application if, for example, running in debug mode and noticing such misuse.
    ///
    /// Implementations SHOULD prevent double-emitting by marking a span as ended internally, however it is a
    /// programming mistake to rely on this behavior.
    ///
    /// - SeeAlso: ``end(at:)`` which allows you to provide a specific time, for example if the operation was ended and recorded somewhere and we need to post-factum record it.
    ///   Prefer to use  the ``end()`` version of this API in user code and structure your system such that it can be called in the right place and time.
    public func end() {
        self.end(at: DefaultTracerClock.now)
    }

    /// Add a link to the span.
    ///
    /// - Parameter other: The `Span` to link to.
    /// - Parameter attributes: The ``SpanAttributes`` describing this link. Defaults to no attributes.
    public func addLink(_ other: Self, attributes: SpanAttributes = [:]) {
        self.addLink(SpanLink(context: other.context, attributes: attributes))
    }
}

extension Span {
    /// Record an error into the span.
    ///
    /// - Parameters:
    ///   - error: The error to record.
    public func recordError(_ error: Error) {
        self.recordError(error, attributes: [:])
    }
}

extension Span {
    /// Update the span attributes in a block instead of individually.
    ///
    /// Updating a span attribute involves some type of thread synchronisation
    /// primitive to avoid multiple threads updating the attributes at the same
    /// time. If you update each attribute individually, this can cause slowdown.
    /// This function updates the attributes in one call to avoid hitting the
    /// thread synchronisation code multiple times.
    ///
    /// - Parameter update: closure used to update span attributes
    public func updateAttributes(_ update: (inout SpanAttributes) -> Void) {
        var attributes = self.attributes
        update(&attributes)
        self.attributes = attributes
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Span Event

/// An event that occurred during a span.
public struct SpanEvent: Equatable {
    /// The human-readable name of this event.
    public let name: String

    /// One or more span attributes.
    ///
    /// The span event attributes have the same restrictions as defined for span attributes.
    public var attributes: SpanAttributes

    /// The timestamp of the event.
    ///
    /// The timestamp is expressed as the number of nanoseconds since UNIX Epoch (January 1st 1970).
    public let nanosecondsSinceEpoch: UInt64

    /// The timestamp of the event represented as the number of milliseconds since UNIX Epoch (January 1st 1970).
    public var millisecondsSinceEpoch: UInt64 {
        self.nanosecondsSinceEpoch / 1_000_000
    }

    /// Create a span event.
    /// - Parameters:
    ///   - name: The human-readable name of this event.
    ///   - attributes: Attributes that describe this event. Defaults to no attributes.
    ///   - instant: The time instant at which the event occurred.
    public init<Instant: TracerInstant>(
        name: String,
        at instant: @autoclosure () -> Instant,
        attributes: SpanAttributes = [:]
    ) {
        self.name = name
        self.attributes = attributes
        self.nanosecondsSinceEpoch = instant().nanosecondsSinceEpoch
    }

    /// Create a span event.
    /// - Parameters:
    ///   - name: The human-readable name of this event.
    ///   - attributes: Attributes that describe this event. Defaults to no attributes.
    public init(
        name: String,
        attributes: SpanAttributes = [:]
    ) {
        self.name = name
        self.attributes = attributes
        self.nanosecondsSinceEpoch = DefaultTracerClock.now.nanosecondsSinceEpoch
    }
}

extension SpanEvent: ExpressibleByStringLiteral {
    /// Create a span event.
    /// - Parameter name: The human-readable name of this event.
    public init(stringLiteral name: String) {
        self.init(name: name)
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Span Attribute

/// A span attribute key.
public struct SpanAttributeKey<T>: Hashable, ExpressibleByStringLiteral where T: SpanAttributeConvertible {
    /// The name of the span attribute key.
    public let name: String

    /// Creates a span attribute key with the name you provide.
    /// - Parameter name: The name of the span attribute key.
    public init(name: String) {
        self.name = name
    }

    /// Creates a span attribute key using a string literal value you provide..
    /// - Parameter value: The name of the span attribute key.
    public init(stringLiteral value: StringLiteralType) {
        self.name = value
    }
}

/// A type that provides a namespace for span attributes.
@dynamicMemberLookup
public protocol SpanAttributeNamespace {
    /// The type that contains the nested attributes for the namespace.
    ///
    /// For example, `HTTPAttributes` contains `statusCode` and similar keys.
    associatedtype NestedSpanAttributes: NestedSpanAttributesProtocol

    /// The attributes of the name space.
    var attributes: SpanAttributes { get set }

    /// Get or update a span attribute with the keypath you provide.
    subscript<T>(dynamicMember dynamicMember: KeyPath<NestedSpanAttributes, SpanAttributeKey<T>>) -> T?
    where T: SpanAttributeConvertible {
        get
        set
    }

    /// Returns the namespace for the keypath you provide.
    subscript<Namespace>(dynamicMember dynamicMember: KeyPath<SpanAttribute, Namespace>) -> Namespace
    where Namespace: SpanAttributeNamespace
    {
        get
    }
}

/// A type that provides nested span attributes.
public protocol NestedSpanAttributesProtocol {
    init()

    /// INTERNAL API
    /// Magic value allowing the dynamicMember lookup inside SpanAttributeNamespaces to work.
    ///
    /// There is no need of ever implementing this function explicitly, the default implementation is good enough.
    static var __namespace: Self { get }
}

extension NestedSpanAttributesProtocol {
    /// Create a nested set of attributes.
    public static var __namespace: Self {
        .init()
    }
}

extension NestedSpanAttributesProtocol {
    /// The type that represents span keys for the nested attributes.
    public typealias Key = SpanAttributeKey
}

extension SpanAttributeNamespace {
    /// Get or update a span attribute with the keypath you provide.
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

    /// Returns the namespace for the keypath you provide.
    public subscript<Namespace>(dynamicMember dynamicMember: KeyPath<SpanAttribute, Namespace>) -> Namespace
    where Namespace: SpanAttributeNamespace {
        SpanAttribute.int(0)[keyPath: dynamicMember]
    }
}

/// The value of an attribute used to describe a span or span event.
///
/// Arrays are allowed but are enforced to be homogenous.
///
/// Attributes cannot be nested, the structure is a flat key/value representation.
public enum SpanAttribute: Equatable {
    /// The type that represents keys for the span attributes.
    public typealias Key = SpanAttributeKey

    /// A 32-bit integer value.
    case int32(Int32)
    /// A 64-bit integer value.
    case int64(Int64)

    /// An array of 32-bit integers.
    case int32Array([Int32])
    /// An array of 64-bit integers.
    case int64Array([Int64])

    /// A floating point value.
    case double(Double)
    /// An array of floating point values.
    case doubleArray([Double])

    /// A Boolean value.
    case bool(Bool)
    /// An array of Boolean values.
    case boolArray([Bool])

    /// A string value.
    case string(String)
    /// An array of strings.
    case stringArray([String])

    case __DO_NOT_SWITCH_EXHAUSTIVELY_OVER_THIS_ENUM_USE_DEFAULT_INSTEAD

    /// A value that converts to a string.
    case stringConvertible(CustomStringConvertible & Sendable)
    /// An array of values that convert to strings.
    case stringConvertibleArray([CustomStringConvertible & Sendable])

    /// Creates a 64-bit integer value.
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
        case .__DO_NOT_SWITCH_EXHAUSTIVELY_OVER_THIS_ENUM_USE_DEFAULT_INSTEAD:
            fatalError("Cannot have values of __DO_NOT_SWITCH_EXHAUSTIVELY_OVER_THIS_ENUM")
        }
    }

    /// Returns a Boolean value that indicates whether two span attributes are equivalent.
    /// - Parameters:
    ///   - lhs: The first span attribute.
    ///   - rhs: The second span attribute.
    /// - Returns: Return `true` if the values are equivalent; otherwise `false`.
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
    /// Returns a span attribute that represents the type.
    public func toSpanAttribute() -> SpanAttribute {
        self
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Attribute Values
//
/// A type that converts to a span attribute.
public protocol SpanAttributeConvertible {
    /// Returns the span attribute that represents the type.
    func toSpanAttribute() -> SpanAttribute
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Attribute Values: Arrays

extension Array where Element == Int {
    /// Returns the span attribute representation of the array of integers.
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

extension Array where Element == Int32 {
    /// Returns the span attribute representation of the array of 32-bit integers.
    public func toSpanAttribute() -> SpanAttribute {
        .int32Array(self)
    }
}

extension Array where Element == Int64 {
    /// Returns the span attribute representation of the array of 64-bit integers.
    public func toSpanAttribute() -> SpanAttribute {
        .int64Array(self)
    }
}

extension Array where Element == Double {
    /// Returns the span attribute representation of the array of floating point numbers.
    public func toSpanAttribute() -> SpanAttribute {
        .doubleArray(self)
    }
}

// fallback implementation
extension Array: SpanAttributeConvertible where Element: SpanAttributeConvertible {
    /// Returns the span attribute representation of the array.
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
    /// Returns the span attribute representation of the string.
    public func toSpanAttribute() -> SpanAttribute {
        .string(self)
    }
}

extension SpanAttribute: ExpressibleByStringLiteral {
    /// Returns the span attribute representation of the string literal.
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension SpanAttribute: ExpressibleByStringInterpolation {
    /// Returns the span attribute representation of the interpolated string value.
    public init(stringInterpolation value: SpanAttribute.StringInterpolation) {
        self = .string("\(value)")
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Attribute Values: Int

extension SpanAttribute: ExpressibleByIntegerLiteral {
    /// Returns the span attribute representation of the integer.
    public init(integerLiteral value: Int) {
        self = .int(Int64(value))
    }
}

extension Int: SpanAttributeConvertible {
    /// Returns the span attribute representation of the integer.
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

extension Int32: SpanAttributeConvertible {
    /// Returns the span attribute representation of the 32-bit integer.
    public func toSpanAttribute() -> SpanAttribute {
        .int32(self)
    }
}

extension Int64: SpanAttributeConvertible {
    /// Returns the span attribute representation of the 64-bit integer.
    public func toSpanAttribute() -> SpanAttribute {
        .int64(self)
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Attribute Values: Float/Double

extension Float: SpanAttributeConvertible {
    /// Returns the span attribute representation of the floating point value.
    public func toSpanAttribute() -> SpanAttribute {
        .double(Double(self))
    }
}

extension Double: SpanAttributeConvertible {
    /// Returns the span attribute representation of the floating point value.
    public func toSpanAttribute() -> SpanAttribute {
        .double(self)
    }
}

extension SpanAttribute: ExpressibleByFloatLiteral {
    /// Returns the span attribute representation of the float literal value.
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Attribute Values: Bool

extension Bool: SpanAttributeConvertible {
    /// Returns the span attribute representation of the Boolean value.
    public func toSpanAttribute() -> SpanAttribute {
        .bool(self)
    }
}

extension SpanAttribute: ExpressibleByBooleanLiteral {
    /// Returns the span attribute representation of the Boolean literal value.
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: SpanAttributes: Namespaces

/// A container of span attributes.
@dynamicMemberLookup
public struct SpanAttributes: Equatable {
    private var _attributes = [String: SpanAttribute]()
}

extension SpanAttributes {
    /// Create a set of attributes from the dictionary you provide.
    ///
    /// - Parameter attributes: The attributes dictionary to wrap.
    public init(_ attributes: [String: SpanAttribute]) {
        self._attributes = attributes
    }

    /// Accesses the span attribute with the given name for reading and writing.
    ///
    /// Please be cautious to not abuse this APIs power to read attributes to "smuggle" values between calls.
    /// Only `ServiceContext` is intended to carry information in a readable fashion between functions / processes / nodes.
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

    /// Returns the span attribue for the name you provide.
    ///
    /// Similar to `subscript(_:)` however returns the stored `SpanAttribute` rather than going through `SpanAttributeConvertible`.
    /// - Parameter name: The name of the span attribute to retrieve.
    public func get(_ name: String) -> SpanAttribute? {
        self._attributes[name]
    }

    /// Updates the span attribute for the name you provide.
    ///
    /// Similar to `subscript(_:)` however accepts a `SpanAttribute` rather than going through `SpanAttributeConvertible`.
    /// - Parameters:
    ///   - name: The name of the span attribute to update.
    ///   - value: The span attribute value.
    public mutating func set(_ name: String, value: SpanAttribute?) {
        self._attributes[name] = value
    }

    /// Iterate over the collection of span attributes, invoking the closure you provide for each key/value pair.
    /// - Parameter callback: The closure to call for each attribute.
    public func forEach(_ callback: (String, SpanAttribute) -> Void) {
        for (key, value) in self._attributes {
            callback(key, value)
        }
    }

    /// Merges the collection of span attributes you provide into the existing span attributes.
    ///
    /// This method overwrites the values of duplicate keys with those of the
    /// `other` attributes.
    ///
    /// - Parameter other: The ``SpanAttributes`` to merge.
    public mutating func merge(_ other: SpanAttributes) {
        self._attributes.merge(other._attributes, uniquingKeysWith: { _, rhs in rhs })
    }

    /// The number of span attributes stored.
    public var count: Int {
        self._attributes.count
    }

    /// Returns true if the collection contains no attributes.
    public var isEmpty: Bool {
        self._attributes.isEmpty
    }
}

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
    where Namespace: SpanAttributeNamespace {
        SpanAttribute._namespace[keyPath: dynamicMember]
    }
}

extension SpanAttributes: ExpressibleByDictionaryLiteral {
    /// Creates a collection of span attributes from the dictionary literal elements you provide.
    /// - Parameter elements: the elements to convert into a collection of span attributes.
    public init(dictionaryLiteral elements: (String, SpanAttribute)...) {
        self._attributes = [String: SpanAttribute](uniqueKeysWithValues: elements)
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Span Status

/// The status of a finished span.
///
/// The status is composed of a status code with an optional descriptive message.
public struct SpanStatus: Equatable {
    /// The status code of the span.
    public let code: Code
    /// A descriptive message that represents the span status.
    public let message: String?

    /// Create a span status.
    ///
    /// - Parameters:
    ///   - code: The ``SpanStatus/Code-swift.enum`` of this `SpanStatus`.
    ///   - message: The optional descriptive message of this `SpanStatus`. Defaults to nil.
    public init(code: Code, message: String? = nil) {
        self.code = code
        self.message = message
    }

    /// A code that represents the status of a span.
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
    ///
    /// This span is the child of a remote `.client` span that was expected to wait for a response.
    case server
    /// Indicates that the span describes a synchronous request to some remote service.
    ///
    /// This span is the parent of a remote `.server` span and waits for its response.
    case client
    /// Indicates that the span describes the parent of an asynchronous request.
    ///
    /// This parent span is expected to end before the corresponding child
    /// `.consumer` span, possibly even before the child span starts. In messaging scenarios with batching,
    /// tracing individual messages requires a new `.producer` span per message to be created.
    case producer
    /// Indicates that the span describes the child of an asynchronous `.producer` request.
    case consumer
    /// Indicates that the span represents an internal operation within an application, as opposed to an operation within remote parents or children.
    case `internal`
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Span Link

/// A link to another span.
///
/// The information stored in `context` and `attributes` may be used to
/// further describe the span the link indicates.
public struct SpanLink {
    /// A service context that contains identifying information about the link target span.
    public let context: ServiceContext

    /// Span attributes that further describe the connection between the spans.
    public let attributes: SpanAttributes

    /// Creates a span link.
    ///
    /// - Parameters:
    ///   - context: The `ServiceContext` identifying the targeted ``Span``.
    ///   - attributes: ``SpanAttributes`` that further describe the link. Defaults to no attributes.
    public init(context: ServiceContext, attributes: SpanAttributes) {
        self.context = context
        self.attributes = attributes
    }
}

extension SpanAttributes: Sendable {}
extension SpanAttribute: Sendable {}  // @unchecked because some payloads are CustomStringConvertible
extension SpanStatus: Sendable {}
extension SpanEvent: Sendable {}
extension SpanKind: Sendable {}
extension SpanStatus.Code: Sendable {}
extension SpanLink: Sendable {}
