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
import Dispatch

/// A `Span` type that follows the OpenTracing/OpenTelemetry spec. The span itself should not be
/// initializable via its public interface. `Span` creation should instead go through `tracer.startSpan`
/// where `tracer` conforms to `TracingInstrument`.
public protocol Span {
    /// The operation name is a human-readable string which concisely identifies the work represented by the `Span`.
    ///
    /// For guideline on how to name `Span`s, please take a look at the
    /// [OpenTelemetry specification](https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/trace/api.md#span).
    var operationName: String { get }

    /// The kind of this span.
    var kind: SpanKind { get }

    /// The status of this span.
    var status: SpanStatus? { get set }

    /// The precise `DispatchTime` of when the `Span` was started.
    var startTimestamp: DispatchTime { get }

    /// The precise `DispatchTime` of when the `Span` has ended.
    var endTimestamp: DispatchTime? { get }

    /// The read-only `BaggageContext` of this `Span`, set when starting this `Span`.
    var baggage: BaggageContext { get }

    /// Add a `SpanEvent` in place.
    /// - Parameter event: The `SpanEvent` to add to this `Span`.
    mutating func addEvent(_ event: SpanEvent)

    /// The attributes describing this `Span`.
    var attributes: SpanAttributes { get set }

    /// Returns true if this `Span` is recording information like events, attributes, status, etc.
    var isRecording: Bool { get }

    /// Add a `SpanLink` in place.
    /// - Parameter link: The `SpanLink` to add to this `Span`.
    mutating func addLink(_ link: SpanLink)

    /// End this `Span` at the given timestamp.
    /// - Parameter timestamp: The `DispatchTime` at which the span ended.
    mutating func end(at timestamp: DispatchTime)
}

extension Span {
    /// Create a copy of this `Span` with the given event added to the existing set of events.
    /// - Parameter event: The new `SpanEvent` to be added to the returned copy.
    /// - Returns: A copy of this `Span` with the given event added to the existing set of events.
    public func addingEvent(_ event: SpanEvent) -> Self {
        var copy = self
        copy.addEvent(event)
        return copy
    }

    /// End this `Span` at the current timestamp.
    public mutating func end() {
        self.end(at: .now())
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Span Event

/// An event that occured during a `Span`.
public struct SpanEvent {
    /// The human-readable name of this `SpanEvent`.
    public let name: String

    /// One or more `SpanAttribute`s with the same restrictions as defined for `Span` attributes.
    public var attributes: SpanAttributes

    /// The `DispatchTime` at which this event occured.
    public let timestamp: DispatchTime

    /// Create a new `SpanEvent`.
    /// - Parameters:
    ///   - name: The human-readable name of this event.
    ///   - attributes: The `SpanAttributes` describing this event. Defaults to no attributes.
    ///   - timestamp: The `DispatchTime` at which this event occured. Defaults to `.now()`.
    public init(name: String, attributes: SpanAttributes = [:], at timestamp: DispatchTime = .now()) {
        self.name = name
        self.attributes = attributes
        self.timestamp = timestamp
    }
}

extension SpanEvent: ExpressibleByStringLiteral {
    public init(stringLiteral name: String) {
        self.init(name: name)
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Span Attribute

/// The value of an attribute used to describe a `Span` or `SpanEvent`.
public enum SpanAttribute {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    // TODO: This could be misused to create a heterogenuous array of attributes, which is not allowed in OT:
    // https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/trace/api.md#set-attributes

    case array([SpanAttribute])
    case stringConvertible(CustomStringConvertible)
}

extension SpanAttribute: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension SpanAttribute: ExpressibleByStringInterpolation {
    public init(stringInterpolation value: Self.StringInterpolation) {
        self = .string("\(value)")
    }
}

extension SpanAttribute: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension SpanAttribute: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension SpanAttribute: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension SpanAttribute: ExpressibleByArrayLiteral {
    public init(arrayLiteral attributes: SpanAttribute...) {
        self = .array(attributes)
    }
}

/// A collection of `SpanAttribute`s.
public struct SpanAttributes {
    private var _attributes = [String: SpanAttribute]()

    /// Create a set of attributes by wrapping the given dictionary.
    /// - Parameter attributes: The attributes dictionary to wrap.
    public init(_ attributes: [String: SpanAttribute]) {
        self._attributes = attributes
    }

    /// Accesses the `SpanAttribute` with the given name for reading and writing.
    /// - Parameter name: The name of the attribute used to identify the attribute.
    /// - Returns: The `SpanAttribute` identified by the given name, or `nil` if it's not present.
    public subscript(_ name: String) -> SpanAttribute? {
        get {
            self._attributes[name]
        } set {
            self._attributes[name] = newValue
        }
    }

    /// Calls the given callback for each attribute stored in this collection.
    /// - Parameter callback: The function to call for each attribute.
    public func forEach(_ callback: (String, SpanAttribute) -> Void) {
        self._attributes.forEach { callback($0.key, $0.1) }
    }

    /// Returns true if the collection contains no attributes.
    public var isEmpty: Bool {
        self._attributes.isEmpty
    }
}

extension SpanAttributes: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, SpanAttribute)...) {
        self._attributes = [String: SpanAttribute](uniqueKeysWithValues: elements)
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Span Status

/// Represents the status of a finished Span. It's composed of a canonical code in conjunction with an optional descriptive message.
public struct SpanStatus {
    public let cannonicalCode: CannonicalCode
    public let message: String?

    /// Create a new `SpanStatus`.
    /// - Parameters:
    ///   - cannonicalCode: The cannonical code of this `SpanStatus`.
    ///   - message: The optional descriptive message of this `SpanStatus`. Defaults to nil.
    public init(cannonicalCode: CannonicalCode, message: String? = nil) {
        self.cannonicalCode = cannonicalCode
        self.message = message
    }

    /// Represents the canonical set of status codes of a finished Span, following
    /// the [Standard GRPC](https://github.com/grpc/grpc/blob/master/doc/statuscodes.md) codes:
    public enum CannonicalCode {
        /// The operation completed successfully.
        case ok
        /// The operation was cancelled (typically by the caller).
        case cancelled
        /// An unknown error.
        case unknown
        /// Client specified an invalid argument. Note that this differs from `.failedPrecondition`. `.invalidArgument` indicates arguments that
        /// are problematic regardless of the state of the system.
        case invalidArgument
        /// Deadline expired before operation could complete. For operations that change the state of the system,
        /// this error may be returned even if the operation has completed successfully.
        case deadlineExceeded
        /// Some requested entity (e.g., file or directory) was not found.
        case notFound
        /// Some entity that we attempted to create (e.g., file or directory) already exists.
        case alreadyExists
        /// The caller does not have permission to execute the specified operation.
        /// `.permissionDenied` must not be used if the caller cannot be identified (use `.unauthenticated` instead for those errors).
        case permissionDenied
        /// Some resource has been exhausted, perhaps a per-user quota, or perhaps the entire file system is out of space.
        case resourceExhausted
        /// Operation was rejected because the system is not in a state required for the operation's execution.
        case failedPrecondition
        /// The operation was aborted, typically due to a concurrency issue like sequencer check failures, transaction aborts, etc.
        case aborted
        /// Operation was attempted past the valid range. E.g., seeking or reading past end of file.
        /// Unlike `.invalidArgument`, this error indicates a problem that may be fixed if the system state changes.
        case outOfRange
        /// Operation is not implemented or not supported/enabled in this service.
        case unimplemented
        /// Internal errors. Means some invariants expected by underlying system has been broken.
        case `internal`
        /// The service is currently unavailable. This is a most likely a transient condition and may be corrected by retrying with a backoff.
        case unavailable
        /// Unrecoverable data loss or corruption.
        case dataLoss
        /// The request does not have valid authentication credentials for the operation.
        case unauthenticated
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Span Kind

/// Describes the relationship between the Span, its parents, and its children in a Trace.
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

/// A link to another `Span`.
/// The other `Span`s information is stored in `context` and `attributes` may be used to
/// further describe the link.
public struct SpanLink {
    /// A `BaggageContext` containing identifying information about the link target `Span`.
    public let context: BaggageContext

    /// `SpanAttributes` further describing the connection between the `Span`s.
    public let attributes: SpanAttributes

    /// Create a new `SpanLink`.
    /// - Parameters:
    ///   - context: The `BaggageContext` identifying the targeted `Span`.
    ///   - attributes: `SpanAttributes` that further describe the link. Defaults to no attributes.
    public init(context: BaggageContext, attributes: SpanAttributes = [:]) {
        self.context = context
        self.attributes = attributes
    }
}
