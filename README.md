# Swift Distributed Tracing

A Distributed Tracing API for Swift.

This is a collection of Swift types enabling the instrumentation of server side applications using tools such as tracers. Our goal is to provide a common foundation that allows to freely choose how to instrument systems with minimal changes to your actual code.

While Swift Distributed Tracing allows building all kinds of _instruments_, which can co-exist in applications transparently, its primary use is instrumenting multi-threaded and distributed systems with Distributed Traces.

---

This project uses the context propagation type defined independently in:

- [swift-service-context](https://github.com/apple/swift-service-context) -- [`ServiceContext`](https://swiftpackageindex.com/apple/swift-service-context/main/documentation/servicecontextmodule/servicecontext) (zero dependencies)

---

## Compatibility

This project is designed in a very open and extensible manner, such that various instrumentation and tracing systems can be built on top of it.

The purpose of the tracing package is to serve as common API for all tracer and instrumentation implementations. Thanks to this, libraries may only need to be instrumented once, and then be used with any tracer which conforms to this API.

<a name="backends"></a>
### Tracing Backends

Compatible `Tracer` implementations:

| Library | Status                     | Description |
| ------- |----------------------------| ----------- |
| [@swift-otel](https://github.com/swift-otel) / [Swift **OTel**](https://github.com/swift-otel/swift-otel) | 🟢 Updated for 1.0 | Exports spans to [**OpenTelemetry Collector**](https://opentelemetry.io/docs/collector/); Compatible with **Zipkin**, **X-Ray** **Jaeger**, and more. |
| _Your library?_ | ...                        | [Get in touch!](https://forums.swift.org/c/server/43) |

If you know of any other library please send in a [pull request](https://github.com/apple/swift-distributed-tracing/compare) to add it to the list, thank you!

### Supported Libraries & Frameworks

The following is a, non-complete, list of a few libraries and frameworks which provide built-in support for distributed tracing.
This list is not complete, however if youd'd like to feature your library in the list below, feel free to open a pull request adding it.


| HTTP Servers/Frameworks  | Integrates     | Status                                                |
|--------------------------|----------------|-------------------------------------------------------|
| [Hummingbird](https://github.com/hummingbird-project/hummingbird) | Tracing | 🟢 Built-in support |
| [Vapor](https://github.com/vapor/vapor) | Tracing | 🟢 Built-in support |
| [Valkey Swift](https://github.com/valkey-io/valkey-swift) | Tracing | 🟢 Built-in support |
| [gRPC Swift 2](https://github.com/grpc/grpc-swift-2) | Tracing | 🟢 `grpc-swift-extras` middleware |
| _Your library?_          | ...            | [Get in touch!](https://forums.swift.org/c/server/43) |

If you know of any other library please send in a [pull request](https://github.com/apple/swift-distributed-tracing/compare) to add it to the list, thank you!

---

## Reference Documentation

Please refer to the **[reference documentation](https://swiftpackageindex.com/apple/swift-distributed-tracing/documentation/tracing)** for detailed guides about adopting distributed tracing in your applications, libraries and frameworks.
