// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "gsoc-swift-tracing",
    products: [
        .library(name: "Instrumentation", targets: ["Instrumentation"]),
        .library(name: "TracingInstrumentation", targets: ["TracingInstrumentation"]),
        .library(name: "NIOInstrumentation", targets: ["NIOInstrumentation"]),
        .library(name: "OpenTelemetryInstrumentationSupport", targets: ["OpenTelemetryInstrumentationSupport"])
    ],
    dependencies: [
        .package(
            name: "swift-baggage-context",
            url: "https://github.com/slashmo/gsoc-swift-baggage-context.git",
            from: "0.2.0"
        ),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.17.0")
    ],
    targets: [
        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Instrumentation

        .target(
            name: "Instrumentation",
            dependencies: [
                .product(name: "Baggage", package: "swift-baggage-context"),
            ]
        ),
        .testTarget(
            name: "InstrumentationTests",
            dependencies: [
                "Instrumentation",
            ]
        ),

        .target(
            name: "TracingInstrumentation",
            dependencies: [
                "Instrumentation"
            ]
        ),
        .testTarget(
            name: "TracingInstrumentationTests",
            dependencies: [
                "Instrumentation",
                "TracingInstrumentation",
                .product(name: "BaggageLogging", package: "swift-baggage-context"),
            ]
        ),

        .target(
            name: "NIOInstrumentation",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                "Instrumentation",
            ]
        ),
        .testTarget(
            name: "NIOInstrumentationTests",
            dependencies: [
                "NIOInstrumentation",
            ]
        ),

        .target(
            name: "OpenTelemetryInstrumentationSupport",
            dependencies: [
                .target(name: "TracingInstrumentation")
            ]
        ),
        .testTarget(
            name: "OpenTelemetryInstrumentationSupportTests",
            dependencies: [
                "OpenTelemetryInstrumentationSupport"
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Performance / Benchmarks

        .target(
            name: "Benchmarks",
            dependencies: [
                .product(name: "Baggage", package: "swift-baggage-context"),
                "SwiftBenchmarkTools",
            ]
        ),
        .target(
            name: "SwiftBenchmarkTools",
            dependencies: []
        ),
    ]
)
