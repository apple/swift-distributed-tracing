// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "gsoc-swift-tracing",
    products: [
        .library(name: "BaggageLogging", targets: ["BaggageLogging"]),
        .library(name: "Instrumentation", targets: ["Instrumentation"]),
        .library(name: "NIOInstrumentation", targets: ["NIOInstrumentation"])
    ],
    dependencies: [
        .package(url: "https://github.com/slashmo/gsoc-swift-baggage-context", .branch("main")),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.17.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.2.0")
    ],
    targets: [
        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Baggage + Logging

        .target(
            name: "BaggageLogging",
            dependencies: [
                .product(name: "Baggage", package: "gsoc-swift-baggage-context"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "BaggageLoggingTests", 
            dependencies: [
                "BaggageLogging",
            ]
        ),
      
        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Instrumentation

        .target(
            name: "Instrumentation",
            dependencies: [
                .product(name: "Baggage", package: "gsoc-swift-baggage-context"),
            ]
        ),
        .testTarget(
            name: "InstrumentationTests",
            dependencies: [
                "Instrumentation",
                "BaggageLogging"
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
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Performance / Benchmarks

        .target(
            name: "Benchmarks",
            dependencies: [
                .product(name: "Baggage", package: "gsoc-swift-baggage-context"),
                "SwiftBenchmarkTools",
            ]
        ),
        .target(
            name: "SwiftBenchmarkTools",
            dependencies: []
        ),
    ]
)
