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

        // Construct a withSpan call matching the invocation of the @Traced macro

        let operationName = StringLiteralExprSyntax(content: function.name.text)
        let withSpanCall: ExprSyntax = "withSpan(\(operationName))"

        // We want to explicitly specify the closure effect specifiers in order
        // to avoid warnings about unused try/await expressions.
        // We might as well explicitly specify the closure return type to help type inference.

        let asyncClause = function.signature.effectSpecifiers?.asyncSpecifier
        let returnClause = function.signature.returnClause
        var throwsClause = function.signature.effectSpecifiers?.throwsClause
        // You aren't allowed to apply "rethrows" as a closure effect
        // specifier, so we have to convert this to a "throws" effect
        if throwsClause?.throwsSpecifier.tokenKind == .keyword(.rethrows) {
            throwsClause?.throwsSpecifier = .keyword(.throws)
        }
        var withSpanExpr: ExprSyntax = """
        \(withSpanCall) { span \(asyncClause)\(throwsClause)\(returnClause)in \(body.statements) }
        """

        // Apply a try / await as necessary to adapt the withSpan expression

        if function.signature.effectSpecifiers?.asyncSpecifier != nil {
            withSpanExpr = "await \(withSpanExpr)"
        }

        if function.signature.effectSpecifiers?.throwsClause != nil {
            withSpanExpr = "try \(withSpanExpr)"
        }

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
