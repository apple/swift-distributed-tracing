// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "swift-distributed-tracing",
    products: [
        // `ServiceContextModule` is part of this product on purpose. swift-service-context depends on this product
        // and renames this module with `moduleAliases`. The alias key must be a target of the product.
        .library(name: "Instrumentation", targets: ["Instrumentation", "ServiceContextModule"]),
        .library(name: "Tracing", targets: ["Tracing"]),
        .library(name: "InMemoryTracing", targets: ["InMemoryTracing"]),
    ],
    targets: [
        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Instrumentation

        .target(
            name: "Instrumentation"
        ),
        .testTarget(
            name: "InstrumentationTests",
            dependencies: [
                .target(name: "Instrumentation")
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: ServiceContextModule

        // Keeps `import ServiceContextModule` and the `ServiceContext` names working. The module was part of
        // swift-service-context before. swift-service-context cannot be a dependency here, because it depends on this
        // package. swift-service-context also declares a target named `ServiceContextModule`. Target names must be
        // unique across the package graph. So swift-service-context renames this module with `moduleAliases` in its
        // own manifest. A build that contains both packages uses the module of swift-service-context.
        .target(
            name: "ServiceContextModule",
            dependencies: [
                .target(name: "Instrumentation")
            ]
        ),
        .testTarget(
            name: "ServiceContextModuleTests",
            dependencies: [
                .target(name: "ServiceContextModule")
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Tracing

        .target(
            name: "Tracing",
            dependencies: [
                .target(name: "Instrumentation"),
                // Not imported by `Tracing`. This makes `import ServiceContextModule` work for clients that only
                // depend on `Tracing`, as they did when `Instrumentation` depended on swift-service-context.
                .target(name: "ServiceContextModule"),
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
