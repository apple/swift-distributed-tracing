public protocol ContextKey {
    associatedtype Value
}

public struct Context {
    private var dict = [ObjectIdentifier: ValueContainer]()

    public init() {}

    public mutating func inject<Key: ContextKey>(_ key: Key.Type, value: Key.Value) {
        self.dict[ObjectIdentifier(key)] = ValueContainer(value: value)
    }

    public func extract<Key: ContextKey>(_ key: Key.Type) -> Key.Value? {
        self.dict[ObjectIdentifier(key)]?.forceUnwrap(key)
    }

    public mutating func remove<Key: ContextKey>(_ key: Key.Type) {
        self.dict[ObjectIdentifier(key)] = nil
    }

    private struct ValueContainer {
        let value: Any

        func forceUnwrap<Key: ContextKey>(_ key: Key.Type) -> Key.Value {
            self.value as! Key.Value
        }
    }
}
