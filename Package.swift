// swift-tools-version:5.9
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-distributed-tracing",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macCatalyst(.v13),
    ],
    products: [
        .library(name: "Instrumentation", targets: ["Instrumentation"]),
        .library(name: "Tracing", targets: ["Tracing"]),
        .library(name: "TracingMacros", targets: ["TracingMacros"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-service-context.git", from: "1.1.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0-latest"),
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
            ]
        ),
        .testTarget(
            name: "TracingTests",
            dependencies: [
                .target(name: "Tracing")
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: TracingMacros

        .target(
            name: "TracingMacros",
            dependencies: [
                .target(name: "Tracing"),
                .target(name: "TracingMacrosImplementation"),
            ]
        ),
        .macro(
            name: "TracingMacrosImplementation",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "TracingMacrosTests",
            dependencies: [
                .target(name: "Tracing"),
                .target(name: "TracingMacros"),
                .target(name: "TracingMacrosImplementation"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)

for target in package.targets {
    var settings = target.swiftSettings ?? []
    settings.append(.enableExperimentalFeature("StrictConcurrency=complete"))
    target.swiftSettings = settings
}
