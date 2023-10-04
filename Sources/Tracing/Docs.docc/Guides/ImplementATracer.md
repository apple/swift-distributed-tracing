# Implement a Tracer

## Overview

This guide is aimed at ``Tracer`` and `Instrument` protocol implementation authors.

This guide is for you if you find yourself in need of implementing your own tracing client such as Zipkin, Jaeger, X-Trace, OpenTelemetry or something similar that is custom to your company or distributed system. It will also complete your understanding of how distributed tracing systems actually work, so even the casual developer may find this guide useful to read through, even if not implementing your own tracers. 

## Do you need an Instrument or a Tracer?

Distributed tracing offers two types of instrumentation protocols: an instrument, and a tracer.

A tracer is-an instrument as well, and further refines it with the ability to start a trace ``Span``.

## Creating an instrument

In order to implement an instrument you need to implement the `Instrument` protocol.
`Instrument` is part of the `Instrumentation` library that `Tracing` depends on and offers the minimal core APIs that allow implementing instrumentation types.

`Instrument` has two requirements:

1. An `Instrument/extract(_:into:using:)` method, which extracts values from a generic carrier (e.g. HTTP headers) and store them into a `ServiceContext` instance
2. An `Instrument/inject(_:into:using:)` method, which takes values from the `ServiceContext` to inject them into a generic carrier (e.g. HTTP headers)

The two methods will be called by instrumented libraries/frameworks at asynchronous boundaries, giving you a chance to
act on the provided information or to add additional information to be carried across these boundaries.

> The [`ServiceContext`](https://swiftpackageindex.com/apple/swift-service-context/documentation/servicecontextmodule) type is declared in the swift-service-context package.

### Creating a `Tracer`

When creating a tracer you will need to implement two types:

1. Your tracer conforming to ``Tracer``
2. A span type conforming to ``Span``

> ``Span`` largely resembles span concept as defined  [OpenTelemetry](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/api.md#span), however this package does not enforce certain rules specified in there - that is left up to a specific open telemetry tracer implementation.

### Defining, injecting and extracting `ServiceContext`

In order to be able to extract and inject values into the `ServiceContext` which is the value that is "carried around" across asynchronous contexts,
we need to declare a `ServiceContextKey`. ServiceContext generally acts as a type-safe dictionary and declaring the keys this way allows us to perform lookups 
returning the expected type of values:

```swift
import Tracing

private enum TraceIDKey: ServiceContextKey {
  typealias Value = String
}

extension ServiceContext {
  var traceID: String? {
    get {
      return self[TraceIDKey.self]
    }
    set {
      self[TraceIDKey.self] = newValue
    }
  }
}
```

Which is then to be used like this:

```swift
var context = Barrage.current ?? ServiceContext.topLevel
context.traceID = "4bf92f3577b34da6a3ce929d0e0e4736"
print(context.traceID ?? "<no-trace-id>")
```

Here we used a `ServiceContext.current` to "_pick up_" the task-local context value, if present,
and if not present we created a new "top level" context item. This API specifically is 
named "top level" to imply that this should be used when first initiating a top level
context propagation context -- whenever possible, prefer to pick up the `current` context.

### Injecting and extracting ServiceContext

When hitting boundaries like an outgoing HTTP request the library will call out to the [configured instrument(s)](#Bootstrapping-the-Instrumentation-System):

For example, an imaginary HTTP client library making a GET request would look somewhat like this:

```swift
func get(url: String) {
  var request = HTTPRequest(url: url)
  if let context = ServiceContext.current {
    InstrumentationSystem.instrument.inject(
        context,
        into: &request.headers,
        using: HTTPHeadersInjector()
    )
    // actually make the HTTP request
  }
}
```

On the receiving side, an HTTP server should use the following `Instrument` API to extract the HTTP headers of the given
`HTTPRequest` _into_ the context and then wrap invoking user code (or the "next" call in a middleware setup) with `ServiceContext.withValue`
which sets the ServiceContext.current task local value:

```swift
func handler(request: HTTPRequest) async throws {
  var requestBaggage = ServiceContext.current ?? .topLevel 
  InstrumentationSystem.instrument.extract(
    request.headers,
    into: &requestBaggage,
    using: HTTPHeadersExtractor()
  )
    
  try await ServiceContext.withValue(requestBaggage) {
      // invoke user code ...
  }
}
```

> In case your library makes use of the `NIOHTTP1.HTTPHeaders` type we already have an `HTTPHeadersInjector` and
`HTTPHeadersExtractor` available as part of the `NIOInstrumentation` library.

For your library/framework to be able to carry `ServiceContext` across asynchronous boundaries, it's crucial that you carry the context throughout your entire call chain in order to avoid dropping metadata.

### Starting and ending spans

The primary goal and user-facing API of a ``Tracer`` is to create spans.

While you will need to implement all methods of the tracer protocol, the most important one is `startSpan`:

```swift
extension MyTracer: Tracer {
    func startSpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> MySpan {
        let span = MySpan(
            operationName: operationName,
            startTime: instant(),
            context: context(),
            kind: kind,
            onEnd: self.onEndSpan
        )
        self.spans.append(span)
        return span
    }
}
```

If you can require Swift 5.7 prefer doing so, and return the concrete ``Span`` type from the `startSpan` method. 
This allows users who decide to use your tracer explicitly, and not via the global bootstrapped system to avoid 
wrapping tracers in existentials which can be beneficial in some situations.

Next, eventually the user started span will be ended and the `Span/end()` method will be invoked:

```swift
public struct MySpan: Tracing.Span {
    // ... implement all protocol requirements of Span ... 

    public func end<Instant: TracerInstant>(at instant: @autoclosure () -> Instant) {
        // store the `endInstant`
        self.tracer.emit(self)
    }
}
```

It is possible to implement a span as a struct or a class, but a ``Span`` **must exhibit reference type behavior**.
In other words, adding an attribute to one reference of a span must be visible in other references to it. 

The ability to implement a span using a struct comes in handy when implementing a "Noop" (do nothing) span and avoids heap allocations. Normal spans though generally will be backed by `class` based storage and should flush themselves to the owning tracer once the span has been ended
