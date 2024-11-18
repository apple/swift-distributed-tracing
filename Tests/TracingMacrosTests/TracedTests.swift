//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2024 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import XCTest
import SwiftSyntaxMacrosTestSupport

import Tracing
import TracingMacros
import TracingMacrosImplementation

#if compiler(>=6.0)

final class TracedMacroTests: XCTestCase {
    func test_tracedMacro_requires_body() {
        assertMacroExpansion(
            """
            @Traced
            func funcWithoutBody()
            """,
            expandedSource: """
            func funcWithoutBody()
            """,
            diagnostics: [
                .init(message: "expected a function with a body", line: 1, column: 1),
            ],
            macros: ["Traced": TracedMacro.self]
        )
    }

    func test_tracedMacro_sync_nothrow() {
        assertMacroExpansion(
            """
            @Traced
            func syncNonthrowingExample(param: Int) {
                print(param)
            }
            """,
            expandedSource: """
            func syncNonthrowingExample(param: Int) {
                withSpan("syncNonthrowingExample") { span in
                    print(param)
                }
            }
            """,
            macros: ["Traced": TracedMacro.self]
        )
    }

    func test_tracedMacro_sync_throws() {
        assertMacroExpansion(
            """
            @Traced
            func syncThrowingExample(param: Int) throws {
                struct ExampleError: Error {
                }
                throw ExampleError()
            }
            """,
            expandedSource: """
            func syncThrowingExample(param: Int) throws {
                try withSpan("syncThrowingExample") { span throws in
                    struct ExampleError: Error {
                    }
                    throw ExampleError()
                }
            }
            """,
            macros: ["Traced": TracedMacro.self]
        )
    }

    func test_tracedMacro_sync_rethrows() {
        assertMacroExpansion(
            """
            @Traced
            func syncRethrowingExample(body: () throws -> Int) rethrows -> Int {
                print("Starting")
                let result = try body()
                print("Ending")
                return result
            }
            """,
            expandedSource: """
            func syncRethrowingExample(body: () throws -> Int) rethrows -> Int {
                try withSpan("syncRethrowingExample") { span throws -> Int in
                    print("Starting")
                    let result = try body()
                    print("Ending")
                    return result
                }
            }
            """,
            macros: ["Traced": TracedMacro.self]
        )
    }

    func test_tracedMacro_async_nothrow() {
        assertMacroExpansion(
            """
            @Traced
            func asyncNonthrowingExample(param: Int) async {
                print(param)
            }
            """,
            expandedSource: """
            func asyncNonthrowingExample(param: Int) async {
                await withSpan("asyncNonthrowingExample") { span async in
                    print(param)
                }
            }
            """,
            macros: ["Traced": TracedMacro.self]
        )
    }

    func test_tracedMacro_async_throws() {
        assertMacroExpansion(
            """
            @Traced
            func asyncThrowingExample(param: Int) async throws {
                try await Task.sleep(for: .seconds(1))
                print("Hello")
            }
            """,
            expandedSource: """
            func asyncThrowingExample(param: Int) async throws {
                try await withSpan("asyncThrowingExample") { span async throws in
                    try await Task.sleep(for: .seconds(1))
                    print("Hello")
                }
            }
            """,
            macros: ["Traced": TracedMacro.self]
        )
    }

    func test_tracedMacro_async_rethrows() {
        assertMacroExpansion(
            """
            @Traced
            func asyncRethrowingExample(body: () async throws -> Int) async rethrows -> Int {
                try? await Task.sleep(for: .seconds(1))
                let result = try await body()
                span.attributes["result"] = result
                return result
            }
            """,
            expandedSource: """
            func asyncRethrowingExample(body: () async throws -> Int) async rethrows -> Int {
                try await withSpan("asyncRethrowingExample") { span async throws -> Int in
                    try? await Task.sleep(for: .seconds(1))
                    let result = try await body()
                    span.attributes["result"] = result
                    return result
                }
            }
            """,
            macros: ["Traced": TracedMacro.self]
        )
    }

    // Testing that this expands correctly, but not including this as a
    // compile-test because withSpan doesn't currently support typed throws.
    func test_tracedMacro_async_typed_throws() {
        assertMacroExpansion(
            """
            @Traced
            func asyncTypedThrowingExample<Err>(body: () async throws(Err) -> Int) async throws(Err) -> Int {
                try? await Task.sleep(for: .seconds(1))
                let result = try await body()
                span.attributes["result"] = result
                return result
            }
            """,
            expandedSource: """
            func asyncTypedThrowingExample<Err>(body: () async throws(Err) -> Int) async throws(Err) -> Int {
                try await withSpan("asyncTypedThrowingExample") { span async throws(Err) -> Int in
                    try? await Task.sleep(for: .seconds(1))
                    let result = try await body()
                    span.attributes["result"] = result
                    return result
                }
            }
            """,
            macros: ["Traced": TracedMacro.self]
        )
    }

    func test_tracedMacro_accessSpan() {
        assertMacroExpansion(
            """
            @Traced
            func example(param: Int) {
                span.attributes["param"] = param
            }
            """,
            expandedSource: """
            func example(param: Int) {
                withSpan("example") { span in
                    span.attributes["param"] = param
                }
            }
            """,
            macros: ["Traced": TracedMacro.self]
        )
    }
}

// MARK: Compile tests

@Traced
func syncNonthrowingExample(param: Int) {
    print(param)
}

@Traced
func syncThrowingExample(param: Int) throws {
    struct ExampleError: Error {}
    throw ExampleError()
}

@Traced
func syncRethrowingExample(body: () throws -> Int) rethrows -> Int {
    print("Starting")
    let result = try body()
    print("Ending")
    return result
}

@Traced
func asyncNonthrowingExample(param: Int) async {
    print(param)
}

@Traced
func asyncThrowingExample(param: Int) async throws {
    try await Task.sleep(for: .seconds(1))
    print("Hello")
}

@Traced
func asyncRethrowingExample(body: () async throws -> Int) async rethrows -> Int {
    try? await Task.sleep(for: .seconds(1))
    let result = try await body()
    span.attributes["result"] = result
    return result
}

@Traced
func example(param: Int) {
    span.attributes["param"] = param
}

#endif
