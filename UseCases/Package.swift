// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "use-cases",
    products: [
        .executable(name: "ManualContextPropagation", targets: ["ManualContextPropagation"]),
        .executable(name: "ManualAsyncHTTPClient", targets: ["ManualAsyncHTTPClient"]),
        .executable(name: "HTTPEndToEnd", targets: ["HTTPEndToEnd"]),
        .executable(name: "InstrumentsAppTracing", targets: ["InstrumentsAppTracing"]),
    ],
    dependencies: [
        .package(name: "gsoc-swift-tracing", path: "../"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.1.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.9.0"),
        .package(
            name: "swift-baggage-context",
            url: "https://github.com/slashmo/gsoc-swift-baggage-context.git",
            from: "0.2.0"
        ),
    ],
    targets: [
        .target(name: "ManualContextPropagation", dependencies: [
            .product(name: "Instrumentation", package: "gsoc-swift-tracing"),
            .product(name: "Baggage", package: "swift-baggage-context"),
        ]),
        .target(name: "ManualAsyncHTTPClient", dependencies: [
            .product(name: "Instrumentation", package: "gsoc-swift-tracing"),
            .product(name: "NIOInstrumentation", package: "gsoc-swift-tracing"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "Baggage", package: "swift-baggage-context"),
        ]),
        .target(name: "HTTPEndToEnd", dependencies: [
            .product(name: "TracingInstrumentation", package: "gsoc-swift-tracing"),
            .product(name: "NIOInstrumentation", package: "gsoc-swift-tracing"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "Baggage", package: "swift-baggage-context"),
            .product(name: "BaggageLogging", package: "swift-baggage-context"),
        ]),
        .target(name: "InstrumentsAppTracing", dependencies: [
            .product(name: "Instrumentation", package: "gsoc-swift-tracing"),
            .product(name: "TracingInstrumentation", package: "gsoc-swift-tracing"),
        ]),
    ]
)
