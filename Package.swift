// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "swift-distributed-tracing",
    products: [
        .library(name: "Instrumentation", targets: ["Instrumentation"]),
        .library(name: "Tracing", targets: ["Tracing"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-distributed-tracing-baggage", .upToNextMinor(from: "0.4.1")),
        // .package(url: "https://github.com/apple/swift-log.git", from: "1.4.4"),
        .package(url: "https://github.com/ktoso/swift-log", .branch("wip-baggage-in-handlers-but-not-api")),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Instrumentation

        .target(
            name: "Instrumentation",
            dependencies: [
                .product(name: "InstrumentationBaggage", package: "swift-distributed-tracing-baggage"),
                .product(name: "Logging", package: "swift-log"),
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

        .executableTarget(
            name: "_TracingBenchmarks",
            dependencies: [
                .product(name: "InstrumentationBaggage", package: "swift-distributed-tracing-baggage"),
                .target(name: "Tracing"),
                .target(name: "_TracingBenchmarkTools"),
            ]
        ),
        .target(
            name: "_TracingBenchmarkTools",
            dependencies: [],
            exclude: ["README_SWIFT.md"]
        ),
    ]
)
