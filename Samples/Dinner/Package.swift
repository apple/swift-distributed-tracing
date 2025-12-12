// swift-tools-version:5.3
//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift Distributed Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
// See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import PackageDescription

let package = Package(
    name: "onboarding",
    platforms: [
        .macOS("13.0.0")
    ],
    products: [
        .executable(name: "onboarding", targets: ["Onboarding"])
    ],
    dependencies: [
        // This example uses the following tracer implementation:
        .package(url: "https://github.com/slashmo/swift-otel", .branch("main")),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "Onboarding",
            dependencies: [
                .product(name: "OpenTelemetry", package: "swift-otel"),
                .product(name: "OtlpGRPCSpanExporting", package: "swift-otel"),
            ]
        )
    ]
)
