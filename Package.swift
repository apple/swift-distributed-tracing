// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "gsoc-swift-tracing",
    products: [
        .library(name: "Baggage", targets: ["Baggage"]),
        .library(name: "BaggageLogging", targets: ["BaggageLogging"]),
        .library(name: "Instrumentation", targets: ["Instrumentation"]),
        .library(name: "NIOInstrumentation", targets: ["NIOInstrumentation"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.17.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.2.0")
    ],
    targets: [
        .target(name: "Baggage"),
        .testTarget(name: "BaggageTests", dependencies: ["Baggage"]),
        
        .target(name: "BaggageLogging", dependencies: [
            "Baggage",
            .product(name: "Logging", package: "swift-log")
        ]),
        .testTarget(name: "BaggageLoggingTests", dependencies: [
            "BaggageLogging",
            .product(name: "Logging", package: "swift-log")
        ]),
        
        .target(name: "Instrumentation", dependencies: ["Baggage"]),
        .testTarget(name: "InstrumentationTests", dependencies: ["Instrumentation", "Baggage"]),
        
        .target(name: "NIOInstrumentation", dependencies: [
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            "Instrumentation"
        ]),
        .testTarget(name: "NIOInstrumentationTests", dependencies: ["NIOInstrumentation", "Instrumentation"])
    ]
)
