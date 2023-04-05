//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift Distributed Tracing project
// authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `stringify` macro, which takes an expression
/// of any type and produces a tuple containing the value of that expression
/// and the source code that produced the value. For example
///
///     #stringify(x + y)
///
///  will expand to
///
///     (x + y, "x + y")
public struct StringifyMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> ExprSyntax {
        guard let argument = node.argumentList.first?.expression else {
            fatalError("compiler bug: the macro does not have any arguments")
        }

        return "(\(argument), \(literal: argument.description))"
    }
}

enum TracedMacroError: Error {
    case message(String)
}

public struct TracedMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Only on functions at the moment. We could handle initializers as well
        // with a bit of work.
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw TracedMacroError.message("@traced only works on functions")
        }

        // FIXME: change this
        if funcDecl.signature.effectSpecifiers?.asyncSpecifier == nil {
            throw TracedMacroError.message(
                "@traced requires an async function"
            )
        }

        // Form the completion handler parameter.
        let resultType: TypeSyntax? = funcDecl.signature.output?.returnType.with(\.leadingTrivia, []).with(\.trailingTrivia, [])

//        let completionHandlerParam =
//            FunctionParameterSyntax(
//                firstName: .identifier("completionHandler"),
//                colon: .colonToken(trailingTrivia: .space),
//                type: "@escaping (\(resultType ?? "")) -> Void" as TypeSyntax
//            )

        // Add the completion handler parameter to the parameter list.
        let parameterList = funcDecl.signature.input.parameterList
        let newParameterList: FunctionParameterListSyntax
        if let lastParam = parameterList.last {
            // We need to add a trailing comma to the preceding list.
            newParameterList = parameterList
//                .removingLast()
//                .appending(
//                    lastParam.with(
//                        \.trailingComma,
//                        .commaToken(trailingTrivia: .space)
//                    )
//                )
//                .appending(completionHandlerParam)
        } else {
            newParameterList = parameterList
//                .appending(completionHandlerParam)
        }

        let callArguments: [String] = try parameterList.map { param in
            guard let argName = param.secondName ?? param.firstName else {
                throw TracedMacroError.message(
                    "@traced argument must have a name"
                )
            }

            if let paramName = param.firstName, paramName.text != "_" {
                return "\(paramName.text): \(argName.text)"
            }

            return "\(argName.text)"
        }

        let call: ExprSyntax =
            "\(funcDecl.identifier)(\(raw: callArguments.joined(separator: ", ")))"

//        // FIXME: We should make CodeBlockSyntax ExpressibleByStringInterpolation,
//        // so that the full body could go here.
//        let newBody: ExprSyntax =
//            """
//
//              await Tracer.withSpan(#function) { __span in
//                await \(call)
//              }
//
//            """

        // Drop the @traced attribute from the new declaration.
        let newAttributeList = AttributeListSyntax(
            funcDecl.attributes?.filter {
                guard case let .attribute(attribute) = $0,
                      let attributeType = attribute.attributeName.as(SimpleTypeIdentifierSyntax.self),
                      let nodeType = node.attributeName.as(SimpleTypeIdentifierSyntax.self)
                else {
                    return true
                }

                return attributeType.name.text != nodeType.name.text
            } ?? []
        )

        let newFunc =
            funcDecl
              .with(
                  \.identifier,
                  "_\(funcDecl.identifier)"
              )
                .with(
                    \.signature,
                    funcDecl.signature
//                        .with(
//                            \.effectSpecifiers,
//                            funcDecl.signature.effectSpecifiers?.with(\.asyncSpecifier, nil)  // drop async
//                        )
//                        .with(\.output, nil)  // drop result type
//                        .with(
//                            \.input,  // add completion handler parameter
//                            funcDecl.signature.input.with(\.parameterList, newParameterList)
//                                .with(\.trailingTrivia, [])
//                        )
                )
                .with(
                    \.body,
                    CodeBlockSyntax(
                        leftBrace: .leftBraceToken(leadingTrivia: .space),
                        statements: CodeBlockItemListSyntax(
                            [
                                CodeBlockItemSyntax(item: .expr("""
                                                                await InstrumentationSystem.tracer.withSpan(#function) { __span in await \(call) }
                                                                """))
                            ]
                        ),
                        rightBrace: .rightBraceToken(leadingTrivia: .space)
                    )
                )
                .with(\.attributes, newAttributeList)
                .with(\.leadingTrivia, .newlines(2))

        return [DeclSyntax(newFunc)]
    }
}
