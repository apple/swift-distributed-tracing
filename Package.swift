// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "gsoc-swift-tracing",
    products: [
        .library(name: "Baggage", targets: ["Baggage"]),
        .library(name: "Instrumentation", targets: ["Instrumentation"]),
        .library(name: "NIOInstrumentation", targets: ["NIOInstrumentation"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.17.0")
    ],
    targets: [
        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Baggage

        .target(
            name: "Baggage",
            dependencies: []
        ),
        .testTarget(
            name: "BaggageTests",
            dependencies: [
                "Baggage"
            ]
        ),

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

        .target(
            name: "NIOInstrumentation",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                "Instrumentation",
            ]),
        .testTarget(
            name: "NIOInstrumentationTests",
            dependencies: [
                "NIOInstrumentation",
                "Instrumentation",
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Performance / Benchmarks

        .target(
            name: "Benchmarks",
            dependencies: [
                "Baggage",
                "SwiftBenchmarkTools",
            ]
        ),
        .target(
            name: "SwiftBenchmarkTools",
            dependencies: []
        ),
    ]
)
