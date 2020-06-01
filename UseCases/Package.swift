// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "use-cases",
    products: [
        .executable(name: "ManualContextPropagation", targets: ["ManualContextPropagation"])
    ],
    dependencies: [
        .package(path: "../")
    ],
    targets: [
        .target(name: "ManualContextPropagation", dependencies: [
            .product(name: "ContextPropagation", package: "gsoc-swift-tracing")
        ])
    ]
)
