//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2026 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// TracingContext keys provide type-safe access to service contexts by declaring the type of value they key at compile-time.
///
/// To give your `TracingContextKey` an explicit name, override the ``TracingContextKey/nameOverride`` property.
///
/// In general, any `TracingContextKey` should be `internal` or `private` to the part of a system using it.
///
/// All access to context items should be performed through an accessor computed property you define as shown below:
///
/// ```swift
/// /// The Key type should be internal (or private).
/// enum TestIDKey: TracingContextKey {
///     typealias Value = String
///     static var nameOverride: String? { "test-id" }
/// }
///
/// extension TracingContext {
///     /// This is some useful property documentation.
///     public internal(set) var testID: String? {
///         get {
///             self[TestIDKey.self]
///         }
///         set {
///             self[TestIDKey.self] = newValue
///         }
///     }
/// }
/// ```
///
/// This pattern allows library authors fine-grained control over which values may be set, and which only get by end-users.
public protocol TracingContextKey: Sendable {
    /// The type of value uniquely identified by this key.
    associatedtype Value: Sendable

    /// The human-readable name of this key.
    ///
    /// This name will be used instead of the type name when a value is printed.
    ///
    /// It MAY also be picked up by an instrument (from Swift Tracing) which serializes context items, such as used as
    /// header name for carried metadata. Though generally speaking header names are NOT required to use the nameOverride,
    /// and MAY use their well known names for header names and so on, as it depends on the specific transport and instrument used.
    ///
    /// For example, a context key representing the W3C "trace-state" header may want to return "trace-state" here,
    /// in order to achieve a consistent look and feel of this context item throughout logging and tracing systems.
    ///
    /// Defaults to `nil`.
    static var nameOverride: String? { get }
}

extension TracingContextKey {
    /// A human-readable name to use for this key instead of the type name.
    public static var nameOverride: String? { nil }

    /// A human-readable String representation of the underlying key.
    ///
    /// If no explicit name is returned by `nameOverride`, the type name is used.
    public static var name: String { AnyTracingContextKey(self).name }
}

/// A type-erased service context key that you use when iterating through the service context.
///
/// Iterate through an ``TracingContext`` using its ``TracingContext/forEach(_:)`` method.
public struct AnyTracingContextKey: Sendable {
    /// The key's type erased to `Any.Type`.
    public let keyType: Any.Type

    private let _nameOverride: String?

    /// A human-readable String representation of the underlying key.
    ///
    /// If no explicit name has been set on the wrapped key the type name is used.
    public var name: String {
        self._nameOverride ?? String(describing: self.keyType.self)
    }

    init<Key: TracingContextKey>(_ keyType: Key.Type) {
        self.keyType = keyType
        self._nameOverride = keyType.nameOverride
    }
}

extension AnyTracingContextKey: Hashable {
    /// A Boolean value that indicates whether two service context keys are equivalent.
    /// - Parameters:
    ///   - lhs: The first service context key.
    ///   - rhs: The second service context key.
    /// - Returns: `True` if equivalent; otherwise `false`.
    public static func == (lhs: AnyTracingContextKey, rhs: AnyTracingContextKey) -> Bool {
        ObjectIdentifier(lhs.keyType) == ObjectIdentifier(rhs.keyType)
    }

    /// Hashes the essential components of this value by feeding them into the given hasher.
    /// - Parameter hasher: The hasher to use when combining the components of this instance.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self.keyType))
    }
}

/// The former name of ``TracingContextKey``.
@available(*, deprecated, renamed: "TracingContextKey")
public typealias ServiceContextKey = TracingContextKey

/// The former name of ``AnyTracingContextKey``.
@available(*, deprecated, renamed: "AnyTracingContextKey")
public typealias AnyServiceContextKey = AnyTracingContextKey
