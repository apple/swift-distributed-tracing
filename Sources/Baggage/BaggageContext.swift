/// A `BaggageContext` is a heterogenous storage type with value semantics for keyed values in a type-safe
/// fashion. Its values are uniquely identified via `BaggageContextKey`s. These keys also dictate the type of
/// value allowed for a specific key-value pair through their associated type `Value`.
///
/// ## Subscript access
/// You may access the stored values by subscripting with a key type conforming to `BaggageContextKey`.
///
///     enum TestIDKey: BaggageContextKey {
///       typealias Value = String
///     }
///
///     var baggage = BaggageContext()
///     // set a new value
///     baggage[TestIDKey.self] = "abc"
///     // retrieve a stored value
///     baggage[TestIDKey.self] ?? "default"
///     // remove a stored value
///     baggage[TestIDKey.self] = nil
///
/// ## Convenience extensions
///
/// Libraries may also want to provide an extension, offering the values that users are expected to reach for
/// using the following pattern:
///
///     extension BaggageContext {
///       var testID: TestIDKey.Value {
///         get {
///           self[TestIDKey.self]
///         } set {
///           self[TestIDKey.self] = newValue
///         }
///       }
///     }
public struct BaggageContext {
    private var _storage = [ObjectIdentifier: ValueContainer]()

    /// Create an empty `BaggageContext`.
    public init() {}

    public subscript<Key: BaggageContextKey>(_ key: Key.Type) -> Key.Value? {
        get {
            self._storage[ObjectIdentifier(key)]?.forceUnwrap(key)
        } set {
            self._storage[ObjectIdentifier(key)] = newValue.map {
                // TODO: consider if keys should allow optional string names; static property on the type?
                ValueContainer(keyName: String(describing: key.self), value: $0)
            }
        }
    }

    public var printableMetadata: [String: CustomStringConvertible] {
        var description = [String: CustomStringConvertible]()
        for (_, value) in self._storage {
            // TODO: key could be not unique
            description[value.keyName] = String(describing: value.value)
        }
        return description
    }

    private struct ValueContainer {
        let keyName: String
        let value: Any

        func forceUnwrap<Key: BaggageContextKey>(_ key: Key.Type) -> Key.Value {
            self.value as! Key.Value
        }
    }
}

/// `BaggageContextKey`s are used as keys in a `BaggageContext`. Their associated type `Value` gurantees type-safety.
public protocol BaggageContextKey {
    /// The type of `Value` uniquely identified by this key.
    associatedtype Value
}
