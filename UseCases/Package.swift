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
        .package(url: "https://github.com/slashmo/gsoc-swift-baggage-context.git", .branch("main")),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.1.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.18.0")
    ],
    targets: [
        .target(name: "ManualContextPropagation", dependencies: [
            .product(name: "Baggage", package: "gsoc-swift-baggage-context"),
            .product(name: "Instrumentation", package: "gsoc-swift-tracing"),
        ]),
        .target(name: "ManualAsyncHTTPClient", dependencies: [
            .product(name: "Baggage", package: "gsoc-swift-baggage-context"),
            .product(name: "Instrumentation", package: "gsoc-swift-tracing"),
            .product(name: "AsyncHTTPClient", package: "async-http-client")
        ]),
        .target(name: "HTTPEndToEnd", dependencies: [
            .product(name: "Baggage", package: "gsoc-swift-baggage-context"),
            .product(name: "BaggageLogging", package: "gsoc-swift-tracing"),
            .product(name: "Instrumentation", package: "gsoc-swift-tracing"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
            .product(name: "NIO", package: "swift-nio")
        ])
    ]
)
