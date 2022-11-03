# Swift Distributed Tracing

A Distributed Tracing API for Swift.

This is a collection of Swift libraries enabling the instrumentation of server side applications using tools such as tracers. Our goal is to provide a common foundation that allows to freely choose how to instrument systems with minimal changes to your actual code.

While Swift Distributed Tracing allows building all kinds of _instruments_, which can co-exist in applications transparently, its primary use is instrumenting multi-threaded and distributed systems with "traces".

## Documentation

Please refer to the docc generated [Reference Guide and API Documentation](TODO).

## Dependencies

This project uses the context propagation type defined independently in:

- 🧳 [swift-distributed-tracing-baggage](https://github.com/apple/swift-distributed-tracing-baggage) -- [`Baggage`](https://apple.github.io/swift-distributed-tracing-baggage/docs/current/InstrumentationBaggage/Structs/Baggage.html) (zero dependencies)

<a name="backends"></a>
## Implementations

Compatible `Tracer` implementations:

| Library | Status | Description |
| ------- | ------ | ----------- |
| [@slashmo](https://github.com/slashmo) / [**OpenTelemetry** Swift](https://github.com/slashmo/opentelemetry-swift) | Complete | Exports spans to OpenTelemetry Collector; **X-Ray** & **Jaeger** propagation available via extensions. |
| [@pokrywka](https://github.com/pokryfka) / [AWS **xRay** SDK Swift](https://github.com/pokryfka/aws-xray-sdk-swift) | Complete (?) | ... |
| _Your library?_ | ... | [Get in touch!](https://forums.swift.org/c/server/43) |

If you know of any other library please send in a [pull request](https://github.com/apple/swift-distributed-tracing/compare) to add it to the list, thank you!

## Libraries & Frameworks

For distributed tracing to be most useful, it needs to be integrated in libraries, especially those serving to inter-connect different processes such as HTTP, or other RPC clients/servers. This then enables end users to reap the benefits of automatic trace propagation across nodes in a system, as well as restoring baggage when incoming messages are received by such library/framework.

The table below illustrates the 

| Library                                          | Status                                                      | Baggage propagation | Automatic spans (e.g. "request" span)                     |
|--------------------------------------------------|-------------------------------------------------------------|-------------------|-----------------------------------------------------------|
| [Swift gRPC](https://github.com/grpc/grpc-swift) | [PR - in progress](https://github.com/grpc/grpc-swift/pull/1510) | WIP               | Pending                                                   |                               |
| _Your library?_                                  |  ...               | ... |[Get in touch!](https://forums.swift.org/c/server/43) |


### Legacy PoC integrations

Previously, before Swift shipped Task Local Values, a number of proof of concept integrations was implemented.
You can refer to them below, and potentially orchestrate efforts to mature those integrations to use the 1.0 version of distributed tracing, at which point those projects **may** adopt it in their primary releases:

| Library | Integrates | Status |
| ------- | ---------- | ------ |
| AsyncHTTPClient | Tracing | Old* [Proof of Concept PR](https://github.com/swift-server/async-http-client/pull/289) |
| Swift gRPC | Tracing | Old* [Proof of Concept PR](https://github.com/grpc/grpc-swift/pull/941) |
| Swift AWS Lambda Runtime | Tracing | Old* [Proof of Concept PR](https://github.com/swift-server/swift-aws-lambda-runtime/pull/167) |
| Swift NIO | Baggage | Old* [Proof of Concept PR](https://github.com/apple/swift-nio/pull/1574) |
| RediStack (Redis) | Tracing | Signalled intent to adopt tracing. |
| Soto AWS Client | Tracing | Signalled intent to adopt tracing. |
| _Your library?_ | ... | [Get in touch!](https://forums.swift.org/c/server/43) | 

> `*` Note that this package was initially developed as a Google Summer of Code project, during which a number of Proof of Concept PR were opened to a number of projects.
>
> These projects are likely to adopt the, now official, Swift Distributed Tracing package in the shape as previewed in those PRs, however they will need updating. Please give the library developers time to adopt the new APIs (or help them by submitting a PR doing so!).

If you know of any other library please send in a [pull request](https://github.com/apple/swift-distributed-tracing/compare) to add it to the list, thank you!

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

### License 

Apache 2.0