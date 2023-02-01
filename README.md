# Swift Distributed Tracing

A Distributed Tracing API for Swift.

This is a collection of Swift libraries enabling the instrumentation of server side applications using tools such as tracers. Our goal is to provide a common foundation that allows to freely choose how to instrument systems with minimal changes to your actual code.

While Swift Distributed Tracing allows building all kinds of _instruments_, which can co-exist in applications transparently, its primary use is instrumenting multi-threaded and distributed systems with Distributed Traces.

> Warning: The docs below, showcasing the 0.3.x series of the logging integration are **deprecated** thanks to the latest inclusion of [metadata providers in swift-log](https://github.com/apple/swift-log/pull/238). With the introduction of [task local values in Swift](https://developer.apple.com/documentation/swift/tasklocal), and metadata providers in swift-log, the `LoggingContext` pattern showcased below has become an _anti-pattern_. Please give us a moment to finish the [new documentation PR #69](https://github.com/apple/swift-distributed-tracing/pull/69), which will explain the new integration style in detail.
> 
> APIs will not change substantially, as we're closing up on announcing version 1.0. Please look forward to beta releases very soon! 

---

This project uses the context propagation type defined independently in:

- 🧳 [swift-distributed-tracing-baggage](https://github.com/apple/swift-distributed-tracing-baggage) -- [`Baggage`](https://apple.github.io/swift-distributed-tracing-baggage/docs/current/InstrumentationBaggage/Structs/Baggage.html) (zero dependencies)

---

## Documentation

> Warning: A significant update of the reference documentation is in thr works right now, please refer to this PR: 

Documentation is published on the Swift Package Index, available here: https://swiftpackageindex.com/apple/swift-distributed-tracing/main/documentation/tracing

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
