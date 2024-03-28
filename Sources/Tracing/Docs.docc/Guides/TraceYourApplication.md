# Trace Your Application

## Overview

This guide is aimed at **application developers** who have some server-side system and want to make use of distributed tracing
in order to improve their understanding and facilitate performance tuning and debugging their services in production or development.

Distributed tracing offers a way to gain additional insight into how your application is performing in production, without having to reconstruct the "big picture" from manually piecing together log lines and figuring out what happened
after what else and _why_. Distributed traces, as the name implies, also span multiple nodes in a microservice architecture
or clustered system, and provide a profiler-like experience to debugging the handling of a "request" or otherwise defined span.

### Setting up

The first step to get metadata propagation and tracing working in your application is picking an instrumentation or tracer.
A complete [list of swift-distributed-tracing implementations](http://github.com/apple/swift-distributed-tracing) 
is available in this project's README. Select an implementation you'd like to use and follow its bootstrap steps.

> Note: Since instrumenting an **application** in practice will always need to pull in an existing tracer implementation,
> in this guide we'll use the community maintained [`swift-otel`](https://github.com/slashmo/swift-otel) 
> tracer, as an example of how you'd start using tracing in your real applications.
> 
> If you'd rather implement your own tracer, refer to <doc:ImplementATracer>.

Once you have selected an implementation, add it as a dependency to your `Package.swift` file. 

```swift
// Depend on the instrumentation library, e.g. swift-otel:
.package(url: "https://github.com/slashmo/swift-otel.git", from: "<latest-version>"),

// This will automatically include a dependency on the swift-distributed-tracing API:
// .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "1.0.0"),
```

Next, add the dependency to your application target. You should follow the [instructions available in the package's README](https://github.com/slashmo/swift-otel) if unsure how to do this.

### Bootstrapping the Tracer

Similar to [swift-log](https://github.com/apple/swift-log) and [swift-metrics](https://github.com/apple/swift-metrics),
the first thing you'll need to do in your application to use tracing, is to bootstrap the global instance of the tracing system.

This will allow not only your code, that we're about to write, to use tracing, but also all other libraries which
have been implemented against the distributed tracing API to use it as well. For example, by configuring the global
tracing system, an HTTP server or client will automatically handle trace propagation for you, so make sure to always
bootstrap your tracer globally, otherwise you might miss out on its crucial context propagation features.

How the tracer library is initialized will differ from library to library, so refer to the respective implementation's
documentation. Once you're ready, pass the tracer or instrument to the `InstrumentationSystem/bootstrap(_:)` method, 
e.g. like this:

```swift
import Tracing // this library

// Import and prepare whatever the specific tracer implementation needs.
// In our example case, we'll prepare the OpenTelemetry tracing system:
import NIO
import OpenTelemetry

let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let otel = OTel(serviceName: "onboarding", eventLoopGroup: group)
try otel.start().wait()

// Bootstrap the tracing system:
InstrumentationSystem.bootstrap(otel.tracer())
```

You'll notice that the API specifically talks about Instrumentation rather than just Tracing.
This is because it is also possible to use various instrumentation systems, e.g. which only take care
of propagating certain `ServiceContext` values across process boundaries, without using tracing itself.

In other words, all tracers are instruments, and the `InstrumentationSystem` works equally for `Instrument`,
as well as ``Tracer`` implementations.

Our guide focuses on tracing through, so let's continue with that in mind.

#### Recommended bootstrap order

Swift offers developers a suite of observability libraries: logging, metrics and tracing. Each of those systems offers a `bootstrap` function. It is useful to stick to a recommended boot order in order to achieve predictable initialization of applications and sub-systems.

Specifically, it is recommended to bootstrap systems in the following order:

1. [Swift Log](https://github.com/apple/swift-log#default-logger-behavior)'s `LoggingSystem`
2. [Swift Metrics](https://github.com/apple/swift-metrics#selecting-a-metrics-backend-implementation-applications-only)' `MetricsSystem`
3. [Swift Distributed Tracing](https://github.com/apple/swift-distributed-tracing)'s `InstrumentationSystem`
4. Finally, any other parts of your application

This is because tracing systems may attempt to emit logs or metrics about their status etc.

If you intend to use trace identifiers for log correlation (i.e. logging a `trace-id` in every log statement that is part of a trace),
then don't forget to also configure a swift-lot `MetadataProvider`.

A typical bootstrap could look something like this:

```swift
import Tracing // API
import Logging // API

import OpenTelemetry // specific Tracing library
import StatsdMetrics // specific Metrics library

extension Logger.MetadataProvider {

    // Include the following OpenTelemetry tracer specific metadata in log statements:
    static let otel = Logger.MetadataProvider { context in
        guard let spanContext = context?.spanContext else { return nil }
        return [
          "trace-id": "\(spanContext.traceID)",
          "span-id": "\(spanContext.spanID)",
        ]
    }
}

// 1) bootstrap swift-log: stdout-logger
LoggingSystem.bootstrap(
  StreamLogHandler.standardOutput,
  metadataProvider: .otel
)

// 2) bootstrap metrics: statsd
let statsdClient = try StatsdClient(host: host, port: port)
MetricsSystem.bootstrap(statsdClient)

// 3) bootstrap swift-distributed-tracing: open-telemetry
let group: MultiThreadedEventLoopGroup = ...
let otel = OTel(serviceName: "onboarding", eventLoopGroup: group)

try otel.start().wait()
InstrumentationSystem.bootstrap(otel.tracer())

// 4) Continue starting your application ...
```

#### Bootstrapping multiple instruments using MultiplexInstrument

If you'd find yourself in need of using multiple instrumentation or tracer implementations you can group them in a `MultiplexInstrument` first, which you then pass along to the `bootstrap` method like this:

```swift
InstrumentationSystem.bootstrap(MultiplexInstrument([
  FancyInstrument(),
  OtherFancyInstrument(),
]))
```

`MultiplexInstrument` will then call out to each instrument it has been initialized with.

### Introducing Trace Spans

The primary way you interact with distributed tracing is by starting ``Span``s.

Spans form hierarchies with their parent spans, and end up being visualized using various tools, usually in a format similar to gant charts. So for example, if we had multiple operations that compose making dinner, they would be modelled as child spans of a main `makeDinner` span. Any sub tasks are again modelled as child spans of any given operation, and so on.

In order to discuss how tracing works, let us first look at a sample trace, before we even take a look at the any source code. This reflects how you may find yourself using tracing once it has been adopted in your microservice or distributed system architecture: there are many services involved, and often times only from a trace you can know where to start looking at a performance or logical regression in the system. 

> Experiment: **Follow along!** You can follow along and explore the generated traces, and the code producing them by opening the sample project located in `Samples/Dinner`!
>
> The sample includes a docker-compose file which starts an [OpenTelemetry](https://opentelemetry.io) [collector](https://opentelemetry.io/docs/collector/), as well as two UIs which can be used to explore the generated traces: 
>
> - [Zipkin](http://zipkin.io) - available at [http://127.0.0.1:9411](http://127.0.0.1:9411)
> - [Jaeger](https://www.jaegertracing.io) - available at [http://127.0.0.1:16686](http://127.0.0.1:16686)
>
> In order to start these containers, navigate to the `Samples/Dinner` project and run `docker-compose`, like this:
>
> ```bash
> $ cd Samples/Dinner
> $ docker-compose -f docker/docker-compose.yaml up --build
> # Starting docker_zipkin_1 ... done
> # Starting docker_jaeger_1 ... done
> # Recreating docker_otel-collector_1 ... done
> # Attaching to docker_jaeger_1, docker_zipkin_1, docker_otel-collector_1
> ```
>
> This will run docker containers with the services described above, and expose their ports via localhost, 
> including the collector to which we now can export our traces from our development machine. 
>
> Keep these containers running, and then, in another terminal window run the sample app that will generate some traces:
>
> ```bash
> $ swift run -c release
> ```

Once you have run the sample app, you need to hit "search" in either trace visualization UI, and navigate through to expand the trace view. You'll be greeted with a trace looking somewhat like this (in Zipkin):

![Make dinner trace diagram](makeDinner-zipkin-01)

Or, if you prefer Jaeger, it'd look something like this:

![Make dinner trace diagram](makeDinner-jaeger-01)

Take a moment to look at the trace spans featured in these diagrams. 

By looking at them, you should be able to get a rough idea what the code is doing. That's right, it is a top-level `makeDinner` method, that seems to be performing a bunch of tasks in order to prepare a nice meal.

You may also notice that all those traces are executing in the same _service_: the `DinnerService`. This means that we only had one process involved in this trace. Further, by investigating this trace, we can spot that the `chopVegetables` parent span starts two child spans: `chop-carrot` and `chop-potato`, but does so **sequentially**! If we were looking to optimize the time it takes for `makeDinner` to complete, parallelizing these vegetable chopping tasks could be a good idea.

Now, let us take a brief look at the code creating all these spans. 

> Tip: You can refer to the full code located in `Samples/Dinner/Sources/Onboarding`.

```swift
import Tracing 

func makeDinner() async throws -> Meal {
  try await withSpan("makeDinner") { _ in
    async let veggies = try chopVegetables()
    async let meat = marinateMeat()
    async let oven = preheatOven(temperature: 350)
    // ...
    return try await cook(veggies, meat, oven)
  }
}

func chopVegetables() async throws -> [Vegetable] {
  await withSpan("chopVegetables") {
    // Chop the vegetables...!
    // 
    // However, since chopping is a very difficult operation, 
    // one chopping task can be performed at the same time on a single service!
    // (Imagine that... we cannot parallelize these two tasks, and need to involve another service).
    let carrot = try await chop(.carrot) 
    let potato = try await chop(.potato) 
    return [carrot, potato]
  }
}

// ... 
```

It seems that the sequential work on the vegetable chopping is not accidental... we cannot do two of those at the same time on a single service. Therefore, let's introduce new services that will handle the vegetable chopping for us! 

For example, we could split out the vegetable chopping into a service on its own, and request it (via an HTTP, gRPC, or `distributed actor` call), to chop some vegetables for us. The resulting trace will have the same information, even though a part of it now has been executing on a different host! To further illustrate that, let us re-draw the previous diagram, while adding node designations to each span:

A trace of such system would then look like this: 

![A new service handling "chopping" tasks is introduced, it has 3 spans about chopping](makeDinner-zipkin-02)

The `DinnerService` reached out to `ChoppingService-1` that it discovered, and then to parallelize the work, it submitted the secondary chopping task to another service (`ChoppingService-2`). Those two tasks are now performed in parallel, leading to a an improved response time of `makeDinner` service call.

Let us have another look at these spans in Jaeger. The search UI will show us both the previous, and latest execution traces, so we can compare how the execution changed over time:

![Search view in Jaeger, showing the different versions of traces](makeDinner-jaeger-02)

The different services are color coded, and we can see them execute in parallel here as well:

![Trace view in Jaeger, spans are parallel now](makeDinner-jaeger-03)

One additional view we can explore in Jaeger is a **flamegraph** based off the traces. Here we can compare the "before" and "after" flamegraphs:

**Before:**

![](makeDinner-jaeger-040-before)

**After:**

![](makeDinner-jaeger-041-after)

By investigating flamegraphs, you are able to figure out the percentage of time spent and dominating certain functions. Our example was a fairly typical change, where we sped up the `chopVegetables` from taking 65% of the `makeDinner` execution, to just 43%. The flamegraph view can be useful in complex applications, in order to quickly locate which methods or services are taking the most time, and would be worth optimizing, as the span overview sometime can get pretty "busy" in a larger system, performing many calls.

This was just a quick introduction to tracing, but hopefully you are now excited to learn more about tracing and using it to monitor and improve your server side Swift applications! In the following sections we'll discuss how to actually instrument your code, and how to make spans effective by including as much relevant information in them as possible.

### Efficiently working with Spans

We already saw the basic API to spawn a trace span, the ``withSpan(_:context:ofKind:at:function:file:line:_:)-8gw3v`` method, but we didn't discuss it in depth yet. In this section we'll discuss how to efficiently work with spans and some common patterns and practices.

Firstly, spans are created using a `withSpan` call and performing the operation contained within the span in the trailing operation closure body. This is important because it automatically, and correctly, delimits the lifetime of the span: from its creation, until the operation closure returns:

```swift
withSpan("Working on my novel") { span in 
  write(.novel)
}


try await withSpan("Working on my exceptional novel") { span in
  try await writeExceptional(.novel)
}
```

The `withSpan` is available both in synchronous and asynchronous contexts. The closure also is passed a `span` object which is a reference-semantics type that is mutable and `Sendable` that tracer implementations must provide. 

A `Span` is an in memory representation of the trace span that can be enriched with various information about this execution. For example, if the span represents an HTTP request, one would typically add **span attributes** for `http.method`, `http.path` etc. 

Throwing an error out of the withSpan's operation closure automatically records an error in the `span`, and ends the span.

> Warning: A ``Span`` must not be ended multiple times and doing so is a programmer error.

#### Span Attributes

Span ``Span/attributes`` are additional information you can record in a ``Span`` which are then associated with the span and accessible in tracing visualization systems. 

While you are free to record any information you want in attributes, it usually is best to  to stick to "well known" and standardized values, in order to make querying for them _across_ services more consistent. We will discuss pre-defined attributes below.

Recording extra attributes in a Span is simple. You can record any information you want into the ``Span/attributes`` object using the subscript syntax, like this: 

```swift
withSpan("showAttributes") { span in 
  span.attributes["http.method"] = "POST"
  span.attributes["http.status_code"] = 200
}
```

Once the span is ``Span/end()``-ed the attributes are flushed along with it to the backend tracing system.

> Tip: Some "well known" attributes are pre-defined for you in [swift-distributed-tracing-extras](https://github.com/apple/swift-distributed-tracing-extras). Or you may decide to define a number of type-safe attributes yourself. 

Attributes show up when you click on a specific ``Span`` in a trace visualization system. For example, like this in Jaeger:

![Attributes show up under the Span in Jaeger](jaeger-attribute)

Note that some attributes, like for example the information about the process emitting the trace are included in the span automatically. Refer to your tracer's documentation to learn more about how to configure what attributes it should include by default. Common things to include are hostnames, region information or other things which can identify the node in a cluster.

#### Predefined type-safe Span Attributes

The tracing API provides a way to declare and re-use well known span attributes in a type-safe way. Many of those are defined in `swift-distributed-tracing-extras`, and allow e.g. for setting HTTP values like this:

For example, you can include the `TracingOpenTelemetrySemanticConventions` into your project like this:

```swift
import PackageDescription

let package = Package(
    // ...
    dependencies: [
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "..."),
        .package(url: "https://github.com/apple/swift-distributed-tracing-extras.git", from: "..."),
    ],
    targets: [
        .target(
            name: "MyTarget",
            dependencies: [
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .product(name: "TracingOpenTelemetrySemanticConventions", package: "swift-distributed-tracing-extras"),
            ]
        ),
      // ...
    ]
)
```

> Note: The extras library is versioned separately from the core tracing package, and at this point has not reached a source-stable 1.0 release yet.

In order to gain a whole set of well-typed attributes which are pre-defined by the [OpenTelemetry](http://opentelemetry.io) initiative. 

For example, like these for HTTP:

```swift
attributes.http.method = "GET"
attributes.http.url = "https://www.swift.org/download"
attributes.http.target = "/download"
attributes.http.host = "www.swift.org"
attributes.http.scheme = "https"
attributes.http.statusCode = 418
attributes.http.flavor = "1.1"
attributes.http.userAgent = "test"
attributes.http.retryCount = 42
```

or these, for database operations–which can be very useful to detect slow queries in your system:

```swift
attributes.db.system = "postgresql"
attributes.db.connectionString = "test"
attributes.db.user = "swift"
attributes.db.statement = "SELECT name, display_lang FROM Users WHERE id={};"
```

Using such standardized attributes allows you, and other developers of other services you interact with, have a consistent and simple to search by attribute namespace.

#### Declaring your own type-safe Span Attributes

You can define your own type-safe span attributes, which is useful if your team or company has a certain set of attributes you like to set in all services; This way it is easier to remember what attributes one should be setting, and what their types should be, because the attributes pop up in your favorite IDE's autocompletion.

Doing so requires some boilerplate, but you only have to do this once, and later on the use-sites of those attributes look quite neat (as you've seen above). Here is how you would declare a custom `http.method` nested attribute:

```swift
extension SpanAttributes {
    /// Semantic conventions for HTTP spans.
    ///
    /// OpenTelemetry Spec: [Semantic conventions for HTTP spans](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.11.0/specification/trace/semantic_conventions/http.md#semantic-conventions-for-http-spans)
    public var http: HTTPAttributes {
        get {
            .init(attributes: self)
        }
        set {
            self = newValue.attributes
        }
    }
}
```

```swift
/// Semantic conventions for HTTP spans.
///
/// OpenTelemetry Spec: [Semantic conventions for HTTP spans](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.11.0/specification/trace/semantic_conventions/http.md#semantic-conventions-for-http-spans)
@dynamicMemberLookup
public struct HTTPAttributes: SpanAttributeNamespace {
    public var attributes: SpanAttributes

    public init(attributes: SpanAttributes) {
        self.attributes = attributes
    }

    public struct NestedSpanAttributes: NestedSpanAttributesProtocol {
        public init() {}

        /// HTTP request method. E.g. "GET".
        public var method: Key<String> { "http.method" }
    }
}
```

### Span Events

Events are similar to logs in the sense that they signal "something happened" during the execution of the ``Span``.

> Note: There is a general tension between logs and trace events, as they can be used to achieve very similar outcomes. Consult the documentation of your tracing solution and how you'll be reading and investigating logs correlated to traces, and vice versa, and stick to a pattern that works best for your project.

Events are recorded into a span like this:

```swift
withSpan("showEvents") { span in 
  if cacheHit { 
    span.addEvent("cache-hit")
    return cachedValue
  }
                               
  span.addEvent("cache-miss")
  return computeValue()
}
```

An event is actually a value of the ``SpanEvent`` type, and carries along with it a ``SpanEvent/nanosecondsSinceEpoch`` as well as additional ``SpanEvent/attributes`` related to this specific event. In other words, if a ``Span`` represents an interval–something with a beginning and an end–a ``SpanEvent`` represents something that happened at a specific point-in-time during that span's execution.

Events usually show up in a in a trace view as points on the timeline (note that some tracing systems are able to do exactly the same when a log statement includes a correlation trace and span ID in its metadata):

**Jaeger:**

![An event during the cook span](makeDinner-jaeger-event)

**Zipkin:**

![An event during the cook span](makeDinner-zipkin-event)

Events cannot be "failed" or "successful", that is a property of a ``Span``, and they do not have anything that would be equivalent to a log level. When a trace span is recorded and collected, so will all events related to it. In that sense, events are different from log statements, because one can easily change a logger to include the "debug level" log statements, but technically no such concept exists for events (although you could simulate it with attributes).

### Integrations

#### Swift-log integration

Swift-log, the logging package for the server ecosystem, offers native integration with task local values using the `Logger/MetadataProvider`, and its primary application is logging tracing metadata values.

The snippet below shows how one can write a metadata provider and manually extract the context and associated metadata value to be included in log statements automatically:

```swift
import Logging
import Tracing

// Either manually extract "some specific tracer"'s context or such library would already provide it
let metadataProvider = Logger.MetadataProvider {
  guard let context = ServiceContext.current else {
    return [:]
  }
  guard let specificContext = context.someSpecificTracerContext else {
    return [:]
  }
  var metadata: Logger.Metadata = [:]
  metadata["trace-id"] = "\(specificContext.traceID)"
  metadata["span-id"] = "\(specificContext.spanID)"
  return metadata
}

LoggingSystem.bootstrap(
    StreamLogHandler.standardOutput,
    metadataProvider: metadataProvider)
```

Often times writing such provider by hand will not be necessary since the tracer library would be providing one for you. So you'd only need to remember to bootstrap the `LoggingSystem` with the specific tracer's metadata provider:

```
import Logging
import Tracing
import OpenTelemetry // https://github.com/slashmo/swift-otel

LoggingSystem.bootstrap(
    StreamLogHandler.standardOutput,
    metadataProvider: .otel) // OTel library's metadata provider
```

A metadata provider will then be automatically invoked whenever log statements are to be emitted, and therefore e.g. such "bare" log statement:

```swift
let log = Logger(label: "KitchenService")

withSpan("cooking") { _ in
  log.info("Cooking a meal")
}
```

would include the expected trace metadata:

```bash
[info] trace_id:... span_id:... Cooking a meal
```
