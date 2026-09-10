// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "swift-distributed-tracing",
    products: [
        .library(name: "ContextStorage", targets: ["ContextStorage"]),
        .library(name: "Instrumentation", targets: ["Instrumentation"]),
        .library(name: "Tracing", targets: ["Tracing"]),
        .library(name: "InMemoryTracing", targets: ["InMemoryTracing"]),
    ],
    targets: [
        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: ContextStorage

        .target(
            name: "ContextStorage"
        ),
        .testTarget(
            name: "ContextStorageTests",
            dependencies: [
                .target(name: "ContextStorage")
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Instrumentation

        .target(
            name: "Instrumentation",
            dependencies: [
                .target(name: "ContextStorage")
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
                .target(name: "ContextStorage"),
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
