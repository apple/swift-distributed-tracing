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
        let (operationName, context, kind, spanName) = try extractArguments(from: node)

        var withSpanCall = FunctionCallExprSyntax("withSpan()" as ExprSyntax)!
        withSpanCall.arguments.append(
            LabeledExprSyntax(
                expression: operationName ?? ExprSyntax(StringLiteralExprSyntax(content: function.name.text))
            )
        )
        func appendComma() {
            withSpanCall.arguments[withSpanCall.arguments.index(before: withSpanCall.arguments.endIndex)]
                .trailingComma = .commaToken()
        }
        if let context {
            appendComma()
            withSpanCall.arguments.append(LabeledExprSyntax(label: "context", expression: context))
        }
        if let kind {
            appendComma()
            withSpanCall.arguments.append(LabeledExprSyntax(label: "ofKind", expression: kind))
        }

        // Introduce a span identifier in scope
        var spanIdentifier: TokenSyntax = "span"
        if let spanName {
            spanIdentifier = .identifier(spanName)
        }

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
            \(withSpanCall) { \(spanIdentifier) \(asyncClause)\(throwsClause)\(returnClause)in \(body.statements) }
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

    static func extractArguments(
        from node: AttributeSyntax
    ) throws -> (
        operationName: ExprSyntax?,
        context: ExprSyntax?,
        kind: ExprSyntax?,
        spanName: String?
    ) {
        // If there are no arguments, we don't have to do any of these bindings
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return (nil, nil, nil, nil)
        }

        func getArgument(label: String) -> ExprSyntax? {
            arguments.first(where: { $0.label?.identifier?.name == label })?.expression
        }

        // The operation name is the first argument if it's unlabeled
        var operationName: ExprSyntax?
        if let firstArgument = arguments.first, firstArgument.label == nil {
            operationName = firstArgument.expression
        }

        let context = getArgument(label: "context")
        let kind = getArgument(label: "ofKind")
        var spanName: String?
        let spanNameExpr = getArgument(label: "span")
        if let spanNameExpr {
            guard let stringLiteral = spanNameExpr.as(StringLiteralExprSyntax.self),
                stringLiteral.segments.count == 1,
                let segment = stringLiteral.segments.first,
                let segmentText = segment.as(StringSegmentSyntax.self)
            else {
                throw MacroExpansionErrorMessage("span name must be a simple string literal")
            }
            let text = segmentText.content.text
            let isValidIdentifier = DeclReferenceExprSyntax("\(raw: text)" as ExprSyntax)?.hasError == false
            let isValidWildcard = text == "_"
            guard isValidIdentifier || isValidWildcard else {
                throw MacroExpansionErrorMessage("'\(text)' is not a valid parameter name")
            }
            spanName = text
        }
        return (
            operationName: operationName,
            context: context,
            kind: kind,
            spanName: spanName
        )
    }

}
#endif

@main
struct TracingMacroPlugin: CompilerPlugin {
    #if compiler(>=6.0)
    let providingMacros: [Macro.Type] = [
        TracedMacro.self
    ]
    #else
    let providingMacros: [Macro.Type] = []
    #endif
}
