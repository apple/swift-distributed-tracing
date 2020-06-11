// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "gsoc-swift-tracing",
    products: [
        .library(name: "BaggageContext", targets: ["BaggageContext"]),
        .library(name: "Instrumentation", targets: ["Instrumentation"]),
        .library(name: "NIOInstrumentation", targets: ["NIOInstrumentation"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.17.0")
    ],
    targets: [
        .target(name: "BaggageContext"),
        .testTarget(name: "BaggageContextTests", dependencies: ["BaggageContext"]),

        .target(name: "Instrumentation", dependencies: ["BaggageContext"]),
        .testTarget(name: "InstrumentationTests", dependencies: ["Instrumentation", "BaggageContext"]),

        .target(name: "NIOInstrumentation", dependencies: [
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            "Instrumentation"
        ]),
        .testTarget(name: "NIOInstrumentationTests", dependencies: ["NIOInstrumentation", "Instrumentation"])
    ]
)
