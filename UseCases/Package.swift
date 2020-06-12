// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "use-cases",
    products: [
        .executable(name: "ManualContextPropagation", targets: ["ManualContextPropagation"]),
        .executable(name: "ManualAsyncHTTPClient", targets: ["ManualAsyncHTTPClient"])
    ],
    dependencies: [
        .package(path: "../"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.1.1")
    ],
    targets: [
        .target(name: "ManualContextPropagation", dependencies: [
            .product(name: "Baggage", package: "gsoc-swift-tracing"),
            .product(name: "Instrumentation", package: "gsoc-swift-tracing"),
        ]),
        .target(name: "ManualAsyncHTTPClient", dependencies: [
            .product(name: "Baggage", package: "gsoc-swift-tracing"),
            .product(name: "Instrumentation", package: "gsoc-swift-tracing"),
            .product(name: "AsyncHTTPClient", package: "async-http-client")
        ])
    ]
)
