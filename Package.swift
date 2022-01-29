// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "swift-distributed-tracing",
    products: [
        .library(name: "Instrumentation", targets: ["Instrumentation"]),
        .library(name: "Tracing", targets: ["Tracing"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-distributed-tracing-baggage.git", .upToNextMinor(from: "0.3.0")),
    ],
    targets: [
        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Instrumentation

        .target(
            name: "Instrumentation",
            dependencies: [
                .product(name: "InstrumentationBaggage", package: "swift-distributed-tracing-baggage"),
            ]
        ),
        .testTarget(
            name: "InstrumentationTests",
            dependencies: [
                .target(name: "Instrumentation"),
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Tracing

        .target(
            name: "Tracing",
            dependencies: [
                .target(name: "Instrumentation"),
            ]
        ),
        .testTarget(
            name: "TracingTests",
            dependencies: [
                .target(name: "Tracing"),
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Performance / Benchmarks

        .target(
            name: "_TracingBenchmarks",
            dependencies: [
                .product(name: "InstrumentationBaggage", package: "swift-distributed-tracing-baggage"),
                .target(name: "Tracing"),
                .target(name: "_TracingBenchmarkTools"),
            ]
        ),
        .target(
            name: "_TracingBenchmarkTools",
            dependencies: []
        ),
    ]
)
