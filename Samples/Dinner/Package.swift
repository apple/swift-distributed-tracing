// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "onboarding",
    platforms: [
        .macOS("14.0.0"),
    ],
    products: [
        .executable(name: "onboarding", targets: ["Onboarding"]),
    ],
    dependencies: [
        // This example uses the following tracer implementation:
        .package(url: "https://github.com/slashmo/swift-otel", .branch("main")),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        .target(name: "Onboarding", dependencies: [
            .product(name: "OpenTelemetry", package: "swift-otel"),
            .product(name: "OtlpGRPCSpanExporting", package: "swift-otel"),
        ]),
    ]
)
