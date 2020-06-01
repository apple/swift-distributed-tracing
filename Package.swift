// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "gsoc-swift-tracing",
    products: [
        .library(name: "ContextPropagation", targets: ["ContextPropagation"])
    ],
    targets: [
        .target(name: "ContextPropagation"),
        .testTarget(name: "ContextPropagationTests", dependencies: ["ContextPropagation"])
    ]
)
