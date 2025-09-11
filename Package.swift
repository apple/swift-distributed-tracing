// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "swift-distributed-tracing",
    products: [
        .library(name: "Instrumentation", targets: ["Instrumentation"]),
        .library(name: "Tracing", targets: ["Tracing"]),
        .library(name: "InMemoryTracing", targets: ["InMemoryTracing"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-service-context.git", from: "1.1.0")
    ],
    targets: [
        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Instrumentation

        .target(
            name: "Instrumentation",
            dependencies: [
                .product(name: "ServiceContextModule", package: "swift-service-context")
            ]
        ),
        .testTarget(
            name: "InstrumentationTests",
            dependencies: [
                .target(name: "Instrumentation")
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Tracing

        .target(
            name: "Tracing",
            dependencies: [
                .product(name: "ServiceContextModule", package: "swift-service-context"),
                .target(name: "Instrumentation"),
                .target(name: "_CWASI", condition: .when(platforms: [.wasi])),
            ]
        ),
        .testTarget(
            name: "TracingTests",
            dependencies: [
                .target(name: "Tracing")
            ]
        ),
        .target(
            name: "InMemoryTracing",
            dependencies: [
                .target(name: "Tracing")
            ]
        ),
        .testTarget(
            name: "InMemoryTracingTests",
            dependencies: [
                .target(name: "InMemoryTracing")
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Wasm Support

        // Provides C shims for compiling to wasm
        .target(
            name: "_CWASI",
            dependencies: []
        ),
    ]
)

for target in package.targets {
    var settings = target.swiftSettings ?? []
    settings.append(.enableExperimentalFeature("StrictConcurrency=complete"))
    target.swiftSettings = settings
}
