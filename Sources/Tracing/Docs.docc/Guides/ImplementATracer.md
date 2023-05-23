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

1. An `Instrument/extract(_:into:using:)` method, which extracts values from a generic carrier (e.g. HTTP headers) and store them into a `Baggage` instance
2. An `Instrument/inject(_:into:using:)` method, which takes values from the `Baggage` to inject them into a generic carrier (e.g. HTTP headers)

The two methods will be called by instrumented libraries/frameworks at asynchronous boundaries, giving you a chance to
act on the provided information or to add additional information to be carried across these boundaries.

> The [`Baggage` documentation](https://github.com/apple/swift-distributed-tracing-baggage) type is declared in the swift-distributed-tracing-baggage package.

### Creating a `Tracer`

When creating a tracer you will need to implement two types:

1. Your tracer conforming to ``Tracer``
2. A span type conforming to ``Span``

> ``Span`` largely resembles span concept as defined  [OpenTelemetry](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/api.md#span), however this package does not enforce certain rules specified in there - that is left up to a specific open telemetry tracer implementation.

### Defining, injecting and extracting Baggage

In order to be able to extract and inject values into the `Baggage` which is the value that is "carried around" across asynchronous contexts,
we need to declare a `BaggageKey`. Baggage generally acts as a type-safe dictionary and declaring the keys this way allows us to perform lookups 
returning the expected type of values:

```swift
import Tracing

private enum TraceIDKey: BaggageKey {
  typealias Value = String
}

extension Baggage {
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
var baggage = Barrage.current ?? Baggage.topLevel
baggage.traceID = "4bf92f3577b34da6a3ce929d0e0e4736"
print(baggage.traceID ?? "<no-trace-id>")
```

Here we used a `Baggage.current` to "_pick up_" the task-local baggage value, if present,
and if not present we created a new "top level" baggage item. This API specifically is 
named "top level" to imply that this should be used when first initiating a top level
context propagation baggage -- whenever possible, prefer to pick up the `current` baggage.

### Injecting and extracting Baggage

When hitting boundaries like an outgoing HTTP request the library will call out to the [configured instrument(s)](#Bootstrapping-the-Instrumentation-System):

For example, an imaginary HTTP client library making a GET request would look somewhat like this:

```swift
func get(url: String) {
  var request = HTTPRequest(url: url)
  if let baggage = Baggage.current {
    InstrumentationSystem.instrument.inject(
        baggage,
        into: &request.headers,
        using: HTTPHeadersInjector()
    )
    // actually make the HTTP request
  }
}
```

On the receiving side, an HTTP server should use the following `Instrument` API to extract the HTTP headers of the given
`HTTPRequest` _into_ the baggage and then wrap invoking user code (or the "next" call in a middleware setup) with `Baggage.withValue`
which sets the Baggage.current task local value:

```swift
func handler(request: HTTPRequest) async throws {
  var requestBaggage = Baggage.current ?? .topLevel 
  InstrumentationSystem.instrument.extract(
    request.headers,
    into: &requestBaggage,
    using: HTTPHeadersExtractor()
  )
    
  try await Baggage.withValue(requestBaggage) {
      // invoke user code ...
  }
}
```

> In case your library makes use of the `NIOHTTP1.HTTPHeaders` type we already have an `HTTPHeadersInjector` and
`HTTPHeadersExtractor` available as part of the `NIOInstrumentation` library.

For your library/framework to be able to carry `Baggage` across asynchronous boundaries, it's crucial that you carry the context throughout your entire call chain in order to avoid dropping metadata.

## Creating an instrument

Creating an instrument means adopting the `Instrument` protocol (or `Tracer` in case you develop a tracer).
`Instrument` is part of the `Instrumentation` library & `Tracing` contains the `Tracer` protocol.

`Instrument` has two requirements:

1. A method to inject values inside a `Baggage` into a generic carrier (e.g. HTTP headers)
2. A method to extract values from a generic carrier (e.g. HTTP headers) and store them in a `Baggage`

The two methods will be called by instrumented libraries/frameworks at asynchronous boundaries, giving you a chance to
act on the provided information or to add additional information to be carried across these boundaries.

> Check out the [`Baggage` documentation](https://github.com/apple/swift-distributed-tracing-baggage) for more information on
how to retrieve values from the `Baggage` and how to set values on it.

### Creating a `Tracer`

When creating a tracer you need to create two types:

1. Your tracer conforming to `Tracer`
2. A span class conforming to `Span`

> The `Span` conforms to the standard rules defined in [OpenTelemetry](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/api.md#span), so if unsure about usage patterns, you can refer to this specification and examples referring to it.

### Defining, injecting and extracting Baggage

```swift
import Tracing

private enum TraceIDKey: BaggageKey {
  typealias Value = String
}

extension Baggage {
  var traceID: String? {
    get {
      return self[TraceIDKey.self]
    }
    set {
      self[TraceIDKey.self] = newValue
    }
  }
}

var context = Baggage.topLevel(logger: ...)
context.baggage.traceID = "4bf92f3577b34da6a3ce929d0e0e4736"
print(context.baggage.traceID ?? "new trace id")
```
