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

/// InstrumentationContext keys provide type-safe access to service contexts by declaring the type of value they key at compile-time.
///
/// To give your `InstrumentationContextKey` an explicit name, override the ``InstrumentationContextKey/nameOverride`` property.
///
/// In general, any `InstrumentationContextKey` should be `internal` or `private` to the part of a system using it.
///
/// All access to context items should be performed through an accessor computed property you define as shown below:
///
/// ```swift
/// /// The Key type should be internal (or private).
/// enum TestIDKey: InstrumentationContextKey {
///     typealias Value = String
///     static var nameOverride: String? { "test-id" }
/// }
///
/// extension InstrumentationContext {
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
public protocol InstrumentationContextKey: Sendable {
    /// The type of value uniquely identified by this key.
    associatedtype Value: Sendable

    /// The human-readable name of this key.
    ///
    /// This name will be used instead of the type name when a value is printed.
    ///
    /// It MAY also be picked up by an instrument (from Swift Tracing) which serializes context items, such as being used as the
    /// header name for carried metadata. Though generally speaking header names are NOT required to use the nameOverride,
    /// and MAY use their well known names for header names and so on, as it depends on the specific transport and instrument used.
    ///
    /// For example, a context key representing the W3C "trace-state" header may want to return "trace-state" here,
    /// in order to achieve a consistent look and feel of this context item throughout logging and tracing systems.
    ///
    /// Defaults to `nil`.
    static var nameOverride: String? { get }
}

extension InstrumentationContextKey {
    /// A human-readable name to use for this key instead of the type name.
    public static var nameOverride: String? { nil }

    /// A human-readable String representation of the underlying key.
    ///
    /// If no explicit name is returned by `nameOverride`, the type name is used.
    public static var name: String { AnyInstrumentationContextKey(self).name }
}

/// A type-erased service context key that you use when iterating through the service context.
///
/// Iterate through an ``InstrumentationContext`` using its ``InstrumentationContext/forEach(_:)`` method.
public struct AnyInstrumentationContextKey: Sendable {
    /// The key's type erased to `Any.Type`.
    public let keyType: Any.Type

    private let _nameOverride: String?

    /// A human-readable String representation of the underlying key.
    ///
    /// If no explicit name has been set on the wrapped key the type name is used.
    public var name: String {
        self._nameOverride ?? String(describing: self.keyType.self)
    }

    init<Key: InstrumentationContextKey>(_ keyType: Key.Type) {
        self.keyType = keyType
        self._nameOverride = keyType.nameOverride
    }
}

extension AnyInstrumentationContextKey: Hashable {
    /// A Boolean value that indicates whether two service context keys are equivalent.
    /// - Parameters:
    ///   - lhs: The first service context key.
    ///   - rhs: The second service context key.
    /// - Returns: `true` if equivalent; otherwise `false`.
    public static func == (lhs: AnyInstrumentationContextKey, rhs: AnyInstrumentationContextKey) -> Bool {
        ObjectIdentifier(lhs.keyType) == ObjectIdentifier(rhs.keyType)
    }

    /// Hashes the essential components of this value by feeding them into the given hasher.
    /// - Parameter hasher: The hasher to use when combining the components of this instance.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self.keyType))
    }
}

/// The former name of ``InstrumentationContextKey``.
@available(*, deprecated, renamed: "InstrumentationContextKey")
public typealias ServiceContextKey = InstrumentationContextKey

/// The former name of ``AnyInstrumentationContextKey``.
@available(*, deprecated, renamed: "AnyInstrumentationContextKey")
public typealias AnyServiceContextKey = AnyInstrumentationContextKey
