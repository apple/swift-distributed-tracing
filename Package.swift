// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "gsoc-swift-tracing",
    products: [
        .library(name: "BaggageContext", targets: ["BaggageContext"]),
        .library(name: "ContextPropagation", targets: ["ContextPropagation"]),
        .library(name: "NIOInstrumentation", targets: ["NIOInstrumentation"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.17.0")
    ],
    targets: [
        .target(name: "BaggageContext"),
        .testTarget(name: "BaggageContextTests", dependencies: ["BaggageContext"]),

        .target(name: "ContextPropagation"),
        .testTarget(name: "ContextPropagationTests", dependencies: ["ContextPropagation"]),

        .target(name: "NIOInstrumentation", dependencies: [
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            "ContextPropagation"
        ]),
        .testTarget(name: "NIOInstrumentationTests", dependencies: ["NIOInstrumentation"])
    ]
)
