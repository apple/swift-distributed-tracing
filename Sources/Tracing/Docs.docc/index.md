# ``Tracing``

A Distributed Tracing API for Swift.

## Overview

This is a collection of Swift libraries enabling the instrumentation of server side applications using tools such as tracers. Our goal is to provide a common foundation that allows to freely choose how to instrument systems with minimal changes to your actual code.

While Swift Distributed Tracing allows building all kinds of _instruments_, which can co-exist in applications transparently, its primary use is instrumenting multi-threaded and distributed systems with Distributed Traces.


---

This project uses the context propagation type defined independently in:

- 🧳 [swift-distributed-tracing-baggage](https://github.com/apple/swift-distributed-tracing-baggage) -- [`Baggage`](https://apple.github.io/swift-distributed-tracing-baggage/docs/current/InstrumentationBaggage/Structs/Baggage.html) (zero dependencies)

## Compatibility

This project is designed in a very open and extensible manner, such that various instrumentation and tracing systems can be built on top of it. 

The purpose of the tracing package is to serve as common API for all tracer and instrumentation implementations. Thanks to this, libraries may only need to be instrumented once, and then be used with any tracer which conforms to this API.

### Tracing Backends
 
Compatible implementations:

| Library | Status | Description |
| ------- | ------ | ----------- |
| [@slashmo](https://github.com/slashmo) / [**OpenTelemetry** Swift](https://github.com/slashmo/opentelemetry-swift) | Complete | Exports spans to OpenTelemetry Collector; **X-Ray** & **Jaeger** propagation available via extensions. |
| [@pokrywka](https://github.com/pokryfka) / [AWS **xRay** SDK Swift](https://github.com/pokryfka/aws-xray-sdk-swift) | Complete (?) | ... |

## Getting Started

In this short getting started example, we'll go through bootstrapping, immediately benefiting from tracing, and instrumenting our own synchronous and asynchronous APIs. The  <doc:InDepthGuide> explain all the pieces of the API in more depth. When in doubt, you may want to refer to the [OpenTelemetry](https://opentelemetry.io), [Zipkin](https://zipkin.io), or [Jaeger](https://www.jaegertracing.io) documentations because all the concepts for different tracers are quite similar. 

### Dependencies & Tracer backend

In order to use tracing you will need to bootstrap a tracing backend (<doc:Tracing#Tracing-Backends>). 

When developing an *application* locate the specific tracer library you would like to use and add it as an dependency directly:

```swift
.package(url: "<https://example.com/some-awesome-tracer-backend.git", from: "..."),
```

Alternatively, or when developing a *library/framework*, you should not depend on a specific tracer, and instead only depend on the tracing package directly, by adding the following to your `Package.swift`:

```
.package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "0.1.0"),
```

To your main target, add a dependency on the `Tracing` library and the instrument you want to use:

```swift
.target(
    name: "MyApplication", 
    dependencies: [
        "Tracing",
        "<AwesomeTracing>", // the specific tracer
    ]
),
```

Then (in an application, libraries should _never_ invoke `bootstrap`), you will want to bootstrap the specific tracer you want to use in your application. A ``TracerProtocol`` is a type of `InstrumentProtocol` and can be offered used to globally bootstrap the tracing system, like this:


```swift
import Tracing // the tracing API
import Logging // the logging API  
import AwesomeTracing // the specific tracer

let awesome = AwesomeTracing()

// bootstrap "awesome tracing" globally:
InstrumentationSystem.bootstrap(awesome)

// also configure a metadata provider for swift-log
LoggingSystem.bootstrap(myHandler, metadataProvider: awesome.metadataProvider)
```

If you don't bootstrap  (or other instrument) the default no-op tracer is used, which will result in no trace data being collected.

### Benefiting from instrumented libraries/frameworks

**Automatically reported spans**: When using an already instrumented library, e.g. an HTTP Server which automatically emits spans internally, this is all you have to do to enable tracing. It should now automatically record and emit spans using your configured backend.

**Using baggage and logging context**: The primary transport type for tracing metadata is called `Baggage` and it is propagated transparently using Swift Concurrency's [task-local values](https://developer.apple.com/documentation/swift/tasklocal). For example, when using an instrumented HTTP server, the API could look like this:

```swift
let log = Logger(label: "testing")

SomeHTTPLibrary.handle { request in
  // Since we configured logging with the metadata provider from "awesome tracing", 
  // we can just directly log messages, and the metadata provider will inject any
  // available tracing metadata (e.g. an example-trace-id).
  log.info("Wow, tracing!")
  return try doSomething()
}
```

In this snippet, we use the context logger to log a very useful message. However it is even more useful than it seems at first sight: if a tracer was installed and extracted tracing information from the incoming request, it would automatically log our message _with_ the trace information, allowing us to co-relate all log statements made during handling of this specific request:

```
05:46:38 example-trace-id=1111-23-1234556 info: Wow tracing!
05:46:38 example-trace-id=9999-22-9879797 info: Wow tracing!
05:46:38 example-trace-id=9999-22-9879797 user=Alice info: doSomething() for user Alice
05:46:38 example-trace-id=1111-23-1234556 user=Charlie info: doSomething() for user Charlie
05:46:38 example-trace-id=1111-23-1234556 user=Charlie error: doSomething() could not complete request!
05:46:38 example-trace-id=9999-22-9879797 user=alice info: doSomething() completed
```

Thanks to tracing, and trace identifiers, even if not using tracing visualization libraries, we can immediately co-relate log statements and know that the request `1111-23-1234556` has failed. Since our application can also _add_ values to the context, we can quickly notice that the error seems to occur for the user `Charlie` and not for user `Alice`. Perhaps the user Charlie has exceeded some quotas, does not have permissions or we have a bug in parsing names that include the letter `h`? We don't know _yet_, but thanks to tracing we can much quicker begin our investigation.

### Instrumenting your code

Adding a span to synchronous functions can be achieved like this:

```swift
func handleRequest(_ op: String) async -> String {
  try Tracer.current.withSpan(operationName: "handleRequest(\(op))") {
    return try dangerousOperation() 
  }
}
```

If this function were asynchronous, and returning a [Swift NIO](https://github.com/apple/swift-nio) `EventLoopFuture`,
we need to end the span when the future completes. We can do so in its `onComplete`:

```swift
func handleRequest(_ op: String) async -> String {
  let tracer = Tracer.current
  let span = tracer.startSpan(operationName: "handleRequest(\(op))")
  
  let future: EventLoopFuture<String> = someOperation(op)
  future.whenComplete { _ in 
    span.end() // oh no, ignored errors!
  }
  
  return future
}
```

This is better, however we ignored the possibility that the future perhaps has failed. If this happens, we would like to report the span as _errored_ because then it will show up as such in tracing backends and we can then easily search for failed operations etc.

To do this within the future we could manually invoke the ``Span/recordError(_:)`` API before ending the span like this:

```swift
func handleRequest(_ op: String) -> EventLoopFuture<String> {
  let tracer = Tracer.current
  let span = tracer.startSpan(operationName: "handleRequest(\(name))")

  let future: EventLoopFuture<String> = someOperation(op)
  future.whenComplete { result in
    switch result {
    case .failure(let error): span.recordError(error)
    case .success(let value): // ... record additional *attributes* into the span
    }
    span.end()
  }

  return future
}
```

While this is verbose, this is only the low-level building blocks that this library provides, higher level helper utilities can be  

> Eventually convenience wrappers will be provided, automatically wrapping future types etc. We welcome such contributions, but likely they should live in `swift-distributed-tracing-extras`.

Once a system, or multiple systems have been instrumented, a ``TracerProtocol`` has been selected and your application runs and emits some trace information, you will be able to inspect how your application is behaving by looking at one of the various trace UIs, such as e.g. Zipkin:

![Simple example trace in Zipkin Web UI](zipkin_trace.png)

## Topics

### Articles

- <doc:InDepthGuide>
