// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "swift-distributed-tracing",
    products: [
        .library(name: "Instrumentation", targets: ["Instrumentation"]),
        .library(name: "Tracing", targets: ["Tracing"]),
        .library(name: "TracingOpenTelemetrySupport", targets: ["TracingOpenTelemetrySupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-distributed-tracing-baggage.git", from: "0.0.1"),
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
            name: "TracingOpenTelemetrySupport",
            dependencies: [
                "Tracing"
            ]
        ),
        .testTarget(
            name: "TracingOpenTelemetrySupportTests",
            dependencies: [
                "TracingOpenTelemetrySupport",
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Performance / Benchmarks

        .target(
            name: "_TracingBenchmarks",
            dependencies: [
                "Baggage",
                "Tracing",
                "TracingOpenTelemetrySupport",
                "_TracingBenchmarkTools",
            ]
        ),
        .target(
            name: "_TracingBenchmarkTools",
            dependencies: []
        ),
    ]
)
