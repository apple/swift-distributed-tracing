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

/// A context is a heterogeneous storage type with value semantics that provides keyed values in a type-safe fashion.
///
/// Its values are uniquely identified with ``InstrumentationContextKey``,  by type identity.
/// These keys also dictate the type of value allowed for a specific key-value pair through their associated type `Value`.
///
/// ### Defining keys and accessing values
/// Define ``InstrumentationContext`` keys as types  which conform to the ``InstrumentationContextKey`` protocol:
/// Specify the types using case-less enums as no actual instances are required.
///
/// ```swift
/// private enum TestIDKey: InstrumentationContextKey {
///   typealias Value = String
/// }
/// ```
///
/// When defining a key, also declare an extension on `InstrumentationContext` to allow convenient and discoverable ways to interact
/// with the context item. The extension should take the form of:
///
///  ```swift
/// extension InstrumentationContext {
///   var testID: String? {
///     get {
///       self[TestIDKey.self]
///     } set {
///       self[TestIDKey.self] = newValue
///     }
///   }
/// }
/// ```
///
/// For consistency, name key types with a `...Key` suffix (for example, `SomethingKey`) and the property
/// used to access a value identifier by such key the prefix of the key (for example `something`).
/// Please also observe the usual Swift naming conventions, such as preferring `ID` to `Id`, and so on.
///
/// ### Usage
/// Using a context container is fairly straightforward, as it boils down to using the prepared computed properties:
///
/// ```swift
/// var context = InstrumentationContext.topLevel
///
/// // set a new value
/// context.testID = "abc"
///
/// // retrieve a stored value
/// let testID = context.testID ?? "default"
///
/// // remove a stored value
/// context.testID = nil
/// ```
///
/// Note that normally a context should not be "created" ad-hoc by user code, but rather passed to it from
/// a runtime. An `InstrumentationContext` may already be available to you through `InstrumentationContext.$current` when using structured concurrency.
/// Otherwise, for example when working in an HTTP server framework, it is most likely that the context is already passed
/// directly or indirectly (such as in a `FrameworkContext`).
///
/// ### Accessing all values
///
/// The only way to access "all" values in a context is the `forEach` function.
/// `InstrumentationContext` intentionally doesn't expose more functions to prevent abuse and developers treating it as too much of an
/// arbitrary value smuggling container.
/// This makes it convenient for tracing and instrumentation systems which need to access either specific or all items carried inside a context.
public struct InstrumentationContext: Sendable {
    private var _storage = [AnyInstrumentationContextKey: Sendable]()

    /// Internal on purpose, please use ``InstrumentationContext/TODO(_:function:file:line:)`` or ``InstrumentationContext/topLevel`` to create an "empty" context,
    /// which carries more meaning to other developers why an empty context was used.
    init() {}
}

// MARK: - Creating InstrumentationContext

extension InstrumentationContext {
    /// Creates a new empty top level context.
    ///
    /// Generally used as an initial context to immediately be populated with some values by a framework or runtime.
    ///
    /// Another use case is for tasks starting in the "background" (such as on a timer),
    /// which don't have a "request context" that they can pick up, and as such they have to create a "top level"
    /// context for their work.
    ///
    /// ### Usage in frameworks and libraries
    /// This function is intended to be used by frameworks and libraries, at the "top-level" where a request's,
    /// message's, or task's processing is initiated. For example, a framework handling requests should create an empty
    /// context when handling a request and immediately populate it with useful trace information extracted from a carrier,
    /// such as an HTTP request and the request's headers.
    ///
    /// ### Usage in applications
    /// Application code should never have to create an empty context during the processing lifetime of any request,
    /// and only create context if some processing is performed in the background - thus the naming of this property.
    ///
    /// Usually, a framework such as an HTTP server or similar "request handler" would already provide users
    /// with a context to pass along through subsequent calls, either implicitly through the task-local `InstrumentationContext.$current`
    /// or explicitly as part of some kind of "FrameworkContext".
    ///
    /// If you are unsure where to obtain a context from, prefer using `.TODO("Not sure where I should get a context from here?")`
    /// in order to inform other developers that the lack of context passing was not done on purpose, but rather because you either
    /// weren't sure where to obtain a context from, or other framework limitations -- for example the outer framework not being
    /// context aware just yet.
    public static var topLevel: InstrumentationContext {
        InstrumentationContext()
    }
}

extension InstrumentationContext {
    /// A context intended as a placeholder until a real value can be passed through a function call.
    ///
    /// This type should ONLY be used while prototyping or when the passing of the proper context is not yet possible,
    /// for example because an external library did not pass it correctly and has to be fixed before the proper context
    /// can be obtained where the TO-DO is currently used.
    ///
    /// ### Crashing on TO-DO context creation
    /// You may set the `SERVICE_CONTEXT_CRASH_TODOS` swift definition while compiling a project in order to make calls to this function crash
    /// with a fatal error, which indicates where a to-do context is used. This comes in handy when you want to ensure that
    /// a project never ends up using code which initially was written as "was lazy, did not pass context", yet the
    /// project requires context passing to be done correctly throughout the application. Similar checks can be performed
    /// at compile time easily using linters (not yet implemented), since it is always valid enough to detect a to-do context
    /// being passed as illegal and warn or error when spotted.
    ///
    /// ### Example
    ///
    /// ```swift
    /// let context = InstrumentationContext.TODO("The framework XYZ should be modified to pass us a context here, and we'd pass it along"))
    /// ```
    ///
    /// - Parameters:
    ///   - reason: Informational reason for developers, why a placeholder context was used instead of a proper one.
    ///   - function: The function to which the TODO refers.
    ///   - file: The file to which the TODO refers.
    ///   - line: The line to which the TODO refers.
    /// - Returns: Empty "to-do" context which should be eventually replaced with a carried through one, or `topLevel`.
    public static func TODO(
        _ reason: StaticString? = "",
        function: String = #function,
        file: String = #file,
        line: UInt = #line
    ) -> InstrumentationContext {
        var context = InstrumentationContext()
        #if BAGGAGE_CRASH_TODOS
        fatalError("BAGGAGE_CRASH_TODOS: at \(file):\(line) (function \(function)), reason: \(reason)")
        #elseif SERVICE_CONTEXT_CRASH_TODOS
        fatalError("SERVICE_CONTEXT_CRASH_TODOS: at \(file):\(line) (function \(function)), reason: \(reason)")
        #else
        context[TODOKey.self] = .init(file: file, line: line)
        return context
        #endif
    }

    private enum TODOKey: InstrumentationContextKey {
        typealias Value = TODOLocation
        static var nameOverride: String? {
            "todo"
        }
    }
}

/// Carried automatically by a "to do" context.
///
/// It can be used to track where a context originated and which "to do" context must be fixed into a real one to avoid this.
public struct TODOLocation: Sendable {
    /// Source file location where the to-do ``InstrumentationContext`` was created
    public let file: String
    /// Source line location where the to-do ``InstrumentationContext`` was created
    public let line: UInt
}

// MARK: - Interacting with InstrumentationContext

extension InstrumentationContext {
    /// Provides type-safe access to the context's values.
    ///
    /// > Note: This API should ONLY be used inside of accessor implementations.
    ///
    /// End users should use "accessors" the key's author MUST define rather than using this subscript, following this pattern:
    ///
    /// ```swift
    /// internal enum TestIDKey: InstrumentationContextKey {
    ///     typealias Value = String
    /// }
    ///
    /// extension InstrumentationContext {
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
    /// This is in order to enforce a consistent style across projects and also allow for fine grained control over
    /// who may set and who may get such property. Just access control to the Key type itself lacks sufficient fidelity.
    ///
    /// Specific context and context types may, and usually do, also offer a way to set context values.
    /// However in the most general case it is not required, as some frameworks may only be able to offer reading.
    public subscript<Key: InstrumentationContextKey>(_ key: Key.Type) -> Key.Value? {
        get {
            guard let value = self._storage[AnyInstrumentationContextKey(key)] else { return nil }
            // safe to force-cast as this subscript is the only way to set a value.
            return (value as! Key.Value)
        }
        set {
            self._storage[AnyInstrumentationContextKey(key)] = newValue
        }
    }
}

extension InstrumentationContext {
    /// The number of items in the context.
    public var count: Int {
        self._storage.count
    }

    /// A Boolean value that indicates whether the context is empty.
    public var isEmpty: Bool {
        self._storage.isEmpty
    }

    /// Iterate through all items in this service context by invoking the given closure for each item.
    ///
    /// The order of those invocations is NOT guaranteed and should not be relied on.
    ///
    /// - Parameter body: The closure to be invoked for each item stored in this `InstrumentationContext`,
    /// passing the type-erased key and the associated value.
    @preconcurrency
    public func forEach(_ body: (AnyInstrumentationContextKey, any Sendable) throws -> Void) rethrows {
        // swift-format-ignore: ReplaceForEachWithForLoop
        try self._storage.forEach { key, value in
            try body(key, value)
        }
    }
}

// MARK: - Propagating InstrumentationContext

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension InstrumentationContext {
    /// A context is automatically propagated through task-local storage.
    ///
    /// This API enables binding a top-level `InstrumentationContext` and
    /// implicitly passes it to child tasks when using structured concurrency.
    @TaskLocal public static var current: InstrumentationContext?

    /// Bind the task-local ``InstrumentationContext/current`` to the passed `value`, and execute the passed `operation`.
    ///
    /// To access the task-local value, use `InstrumentationContext.current`.
    ///
    /// SeeAlso: [Swift Task Locals](https://developer.apple.com/documentation/swift/tasklocal)
    public static func withValue<T>(_ value: InstrumentationContext?, operation: () throws -> T) rethrows -> T {
        try InstrumentationContext.$current.withValue(value, operation: operation)
    }

    /// Bind the task-local ``InstrumentationContext/current`` to the passed `value`, and execute the passed `operation`.
    ///
    /// To access the task-local value, use `InstrumentationContext.current`.
    ///
    /// SeeAlso: [Swift Task Locals](https://developer.apple.com/documentation/swift/tasklocal)
    public static func withValue<T>(
        _ value: InstrumentationContext?,
        isolation: isolated (any Actor)? = #isolation,
        operation: () async throws -> T
    ) async rethrows -> T {
        try await InstrumentationContext.$current.withValue(value, operation: operation)
    }

    /// Bind the task-local ``InstrumentationContext/current`` to the passed `value`, and execute the passed `operation`.
    ///
    /// To access the task-local value, use `InstrumentationContext.current`.
    ///
    /// SeeAlso: [Swift Task Locals](https://developer.apple.com/documentation/swift/tasklocal)
    @available(*, deprecated, message: "Use the method with the isolation parameter instead.")
    // Deprecated trick to avoid executor hop here; 6.0 introduces the proper replacement: #isolation
    @_disfavoredOverload
    public static func withValue<T>(
        _ value: InstrumentationContext?,
        operation: () async throws -> T
    ) async rethrows -> T {
        try await InstrumentationContext.$current.withValue(value, operation: operation)
    }
}

/// The former name of ``InstrumentationContext``.
@available(*, deprecated, renamed: "InstrumentationContext")
public typealias ServiceContext = InstrumentationContext
