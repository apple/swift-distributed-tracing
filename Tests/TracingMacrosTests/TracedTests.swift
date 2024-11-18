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
func example(param: Int) {
    span.attributes["param"] = param
}

#endif
