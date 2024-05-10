// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "swift-distributed-tracing",
    products: [
        .library(name: "Instrumentation", targets: ["Instrumentation"]),
        .library(name: "Tracing", targets: ["Tracing"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-service-context.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Instrumentation

        .target(
            name: "Instrumentation",
            dependencies: [
                .product(name: "ServiceContextModule", package: "swift-service-context"),
            ],
            swiftSettings: [
              .enableExperimentalFeature("StrictConcurrency"),
              .unsafeFlags([
                "-Xfrontend", "-disable-availability-checking"
//                "-enable-experimental-feature IsolatedAny"
              ])
            ]
        ),
        .testTarget(
            name: "InstrumentationTests",
            dependencies: [
                .target(name: "Instrumentation"),
            ],
            swiftSettings: [
              .enableExperimentalFeature("StrictConcurrency"),
              .unsafeFlags([
                "-Xfrontend", "-disable-availability-checking"
//                "-enable-experimental-feature IsolatedAny"
              ])
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Tracing

        .target(
            name: "Tracing",
            dependencies: [
                .target(name: "Instrumentation"),
            ],
            swiftSettings: [
              .enableExperimentalFeature("StrictConcurrency"),
              .unsafeFlags([
                "-Xfrontend", "-disable-availability-checking"
//                "-enable-experimental-feature IsolatedAny"
              ])
            ]
        ),
        .testTarget(
            name: "TracingTests",
            dependencies: [
                .target(name: "Tracing"),
            ],
            swiftSettings: [
              .enableExperimentalFeature("StrictConcurrency"),
              .unsafeFlags([
                "-Xfrontend", "-disable-availability-checking"
//                "-enable-experimental-feature IsolatedAny"
              ])
            ]
        ),
    ]
)
