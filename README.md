# Swift Distributed Tracing

A Distributed Tracing API for Swift.

This is a collection of Swift libraries enabling the instrumentation of server side applications using tools such as tracers. Our goal is to provide a common foundation that allows to freely choose how to instrument systems with minimal changes to your actual code.

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
| [@slashmo](https://github.com/slashmo) / [Swift **OTel**](https://github.com/slashmo/swift-otel) | 🟢 Updated for 1.0 | Exports spans to [**OpenTelemetry Collector**](https://opentelemetry.io/docs/collector/); Compatible with **Zipkin**, **X-Ray** **Jaeger**, and more. |
| _Your library?_ | ...                        | [Get in touch!](https://forums.swift.org/c/server/43) |

If you know of any other library please send in a [pull request](https://github.com/apple/swift-distributed-tracing/compare) to add it to the list, thank you!

### Libraries & Frameworks

As this API package was just released, no projects have yet fully adopted it, the following table for not serves as reference to prior work in adopting tracing work. As projects move to adopt tracing completely, the table will be used to track adoption phases of the various libraries.

| HTTP Servers/Frameworks  | Integrates     | Status                                                |
|--------------------------|----------------|-------------------------------------------------------|
| [Hummingbird](https://github.com/hummingbird-project/hummingbird) | Tracing | 🟢 Built-in support |
| [Vapor](https://github.com/vapor/vapor) | Tracing | [Support planned](https://github.com/vapor/vapor/issues/3033) |
| _Your library?_          | ...            | [Get in touch!](https://forums.swift.org/c/server/43) | 

If you know of any other library please send in a [pull request](https://github.com/apple/swift-distributed-tracing/compare) to add it to the list, thank you!

---

## Reference Documentation

Please refer to the **[reference documentation](https://swiftpackageindex.com/apple/swift-distributed-tracing/documentation/tracing)** for detailed guides about adopting distributed tracing in your applications, libraries and frameworks.

---

## Contributing

Please make sure to run the `./scripts/soundness.sh` script when contributing, it checks formatting and similar things.

You can ensure it always is run and passes before you push by installing a pre-push hook with git:

``` sh
echo './scripts/soundness.sh' > .git/hooks/pre-push
```

### Formatting 

We use a specific version of [`nicklockwood/swiftformat`](https://github.com/nicklockwood/swiftformat).
Please take a look at our [`Dockerfile`](docker/Dockerfile) to see which version is currently being used and install it
on your machine before running the script.
