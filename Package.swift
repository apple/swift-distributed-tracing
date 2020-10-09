// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "swift-distributed-tracing",
    products: [
        .library(name: "Instrumentation", targets: ["Instrumentation"]),
        .library(name: "Tracing", targets: ["Tracing"]),
        .library(name: "OpenTelemetryInstrumentationSupport", targets: ["OpenTelemetryInstrumentationSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-distributed-tracing-baggage.git", from: "0.0.1"),
        .package(url: "https://github.com/apple/swift-distributed-tracing-baggage-core.git", from: "0.0.1"),
    ],
    targets: [
        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Instrumentation

        .target(
            name: "Instrumentation",
            dependencies: [
                "Baggage",
            ]
        ),
        .testTarget(
            name: "InstrumentationTests",
            dependencies: [
                "Instrumentation",
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Tracing

        .target(
            name: "Tracing",
            dependencies: [
                "Instrumentation",
            ]
        ),
        .testTarget(
            name: "TracingTests",
            dependencies: [
                "Tracing",
            ]
        ),

        // ==== ----------------------------------------------------------------------------------------------------------------
        // MARK: Support libraries

        .target(
            name: "OpenTelemetryInstrumentationSupport",
            dependencies: [
                "Tracing"
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
