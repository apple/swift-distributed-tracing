// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "gsoc-swift-tracing",
    products: [
        .library(name: "Instrumentation", targets: ["Instrumentation"]),
        .library(name: "Tracing", targets: ["Tracing"]),
        .library(name: "NIOInstrumentation", targets: ["NIOInstrumentation"]),
        .library(name: "OpenTelemetryInstrumentationSupport", targets: ["OpenTelemetryInstrumentationSupport"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/slashmo/gsoc-swift-baggage-context.git",
            from: "0.5.0"
        ),
        .package(url: "https://github.com/slashmo/swift-nio.git", .branch("feature/baggage-context")),
    ],
    targets: [
        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Instrumentation

        .target(
            name: "Instrumentation",
            dependencies: [
                "Baggage",
                "BaggageContext",
            ]
        ),
        .testTarget(
            name: "InstrumentationTests",
            dependencies: [
                "BaggageContext",
                "Instrumentation",
            ]
        ),

        .target(
            name: "Tracing",
            dependencies: [
                "BaggageContext",
                "Instrumentation",
            ]
        ),
        .testTarget(
            name: "TracingTests",
            dependencies: [
                "Instrumentation",
                "Tracing",
                "BaggageContext",
            ]
        ),

        .target(
            name: "NIOInstrumentation",
            dependencies: [
                "NIO",
                "NIOHTTP1",
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
                .target(name: "Tracing")
            ]
        ),
        .testTarget(
            name: "OpenTelemetryInstrumentationSupportTests",
            dependencies: [
                "OpenTelemetryInstrumentationSupport",
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Performance / Benchmarks

        .target(
            name: "TracingBenchmarks",
            dependencies: [
                "Baggage",
                "TracingBenchmarkTools",
            ]
        ),
        .target(
            name: "TracingBenchmarkTools",
            dependencies: []
        ),
    ]
)
