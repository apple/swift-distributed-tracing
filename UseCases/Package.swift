// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "use-cases",
    products: [
        .executable(name: "ManualContextPropagation", targets: ["ManualContextPropagation"]),
        .executable(name: "ManualAsyncHTTPClient", targets: ["ManualAsyncHTTPClient"]),
        .executable(name: "HTTPEndToEnd", targets: ["HTTPEndToEnd"])
    ],
    dependencies: [
        .package(name: "gsoc-swift-tracing", path: "../"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.1.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.9.0"),
    ],
    targets: [
        .target(name: "ManualContextPropagation", dependencies: [
            .product(name: "Instrumentation", package: "gsoc-swift-tracing"),
        ]),
        .target(name: "ManualAsyncHTTPClient", dependencies: [
            .product(name: "Instrumentation", package: "gsoc-swift-tracing"),
            .product(name: "NIOInstrumentation", package: "gsoc-swift-tracing"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
            .product(name: "NIO", package: "swift-nio"),
        ]),
        .target(name: "HTTPEndToEnd", dependencies: [
            .product(name: "BaggageLogging", package: "gsoc-swift-tracing"),
            .product(name: "Instrumentation", package: "gsoc-swift-tracing"),
            .product(name: "NIOInstrumentation", package: "gsoc-swift-tracing"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
            .product(name: "NIO", package: "swift-nio"),
        ])
    ]
)
