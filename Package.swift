// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "swift-distributed-tracing",
    products: [
        .library(name: "Instrumentation", targets: ["Instrumentation"]),
        .library(name: "Tracing", targets: ["Tracing"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-service-context.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Instrumentation

        .target(
            name: "Instrumentation",
            dependencies: [
                .product(name: "ServiceContextModule", package: "swift-service-context"),
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
                .product(name: "ServiceContextModule", package: "swift-service-context"),
                .target(name: "Tracing"),
                .target(name: "_TracingBenchmarkTools"),
            ]
        ),
        .target(
            name: "_TracingBenchmarkTools",
            dependencies: [
                .target(name: "Instrumentation"),
            ],
            exclude: ["README_SWIFT.md"]
        ),
    ]
)
