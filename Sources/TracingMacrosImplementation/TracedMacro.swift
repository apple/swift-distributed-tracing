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
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

#if compiler(>=6.0)
public struct TracedMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let function = declaration.as(FunctionDeclSyntax.self),
              let body = function.body
        else {
            throw MacroExpansionErrorMessage("expected a function with a body")
        }

        let operationName = StringLiteralExprSyntax(content: function.name.text)
        let withSpanCall: ExprSyntax = "withSpan(\(operationName))"
        let withSpanExpr: ExprSyntax = "\(withSpanCall) { span in \(body.statements) }"

        return ["\(withSpanExpr)"]
    }
}
#endif

@main
struct TracingMacroPlugin: CompilerPlugin {
#if compiler(>=6.0)
    let providingMacros: [Macro.Type] = [
        TracedMacro.self,
    ]
#else
    let providingMacros: [Macro.Type] = []
#endif
}
