# Implement a Tracer

## Overview

This guide is aimed at ``TracerProtocol`` and ``InstrumentProtocol`` implementation authors.

This guide is for you, if you find yourself in need of implementing your own tracing client such as Zipkin, Jaeger, X-Trace, OpenTelemetry or something similar that is custom to your company or distributed system.

## Do you need an Instrument or a Tracer?

Distributed tracing offers two types of instrumentation protocols: an instrument, and a tracer.

A tracer is-an instrument as well, and further refines it with the ability to start a trace ``Span``.

## Creating an instrument

Creating an instrument means adopting the ``Instrument`` protocol (or ``Tracer`` in case you develop a tracer).
`Instrument` is part of the `Instrumentation` library & `Tracing` contains the ``Tracer`` protocol.

`Instrument` has two requirements:

1. A method to inject values inside a `LoggingContext` into a generic carrier (e.g. HTTP headers)
2. A method to extract values from a generic carrier (e.g. HTTP headers) and store them in a `LoggingContext`

The two methods will be called by instrumented libraries/frameworks at asynchronous boundaries, giving you a chance to
act on the provided information or to add additional information to be carried across these boundaries.

> Check out the [`Baggage` documentation](https://github.com/apple/swift-distributed-tracing-baggage) for more information on
how to retrieve values from the `LoggingContext` and how to set values on it.

### Creating a `Tracer`

When creating a tracer you need to create two types:

1. Your tracer conforming to ``Tracer``
2. A span class conforming to ``Span``

> ``Span`` conforms to the standard rules defined in [OpenTelemetry](https://github.com/open-telemetry/opentelemetry-specification/blob/v0.7.0/specification/trace/api.md#span), so if unsure about usage patterns, you can refer to this specification and examples referring to it.

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

var context = DefaultLoggingContext.topLevel(logger: ...)
context.baggage.traceID = "4bf92f3577b34da6a3ce929d0e0e4736"
print(context.baggage.traceID ?? "new trace id")
```


### Extracting & injecting Baggage

When hitting boundaries like an outgoing HTTP request you call out to the [configured instrument(s)](#Bootstrapping-the-Instrumentation-System):

An HTTP client e.g. should inject the given `LoggingContext` into the HTTP headers of its outbound request:

```swift
func get(url: String, context: LoggingContext) {
  var request = HTTPRequest(url: url)
  InstrumentationSystem.instrument.inject(
    context.baggage,
    into: &request.headers,
    using: HTTPHeadersInjector()
  )
}
```

On the receiving side, an HTTP server should use the following `Instrument` API to extract the HTTP headers of the given
`HTTPRequest` into:

```swift
func handler(request: HTTPRequest, context: LoggingContext) {
  InstrumentationSystem.instrument.extract(
    request.headers,
    into: &context.baggage,
    using: HTTPHeadersExtractor()
  )
  // ...
}
```

> In case your library makes use of the `NIOHTTP1.HTTPHeaders` type we already have an `HTTPHeadersInjector` &
`HTTPHeadersExtractor` available as part of the `NIOInstrumentation` library.

For your library/framework to be able to carry `LoggingContext` across asynchronous boundaries, it's crucial that you carry the context throughout your entire call chain in order to avoid dropping metadata.

### Tracing your library

When your library/framework can benefit from tracing, you should make use of it by integrating the `Tracing` library.

In order to work with the tracer [configured by the end-user](#Bootstrapping-the-Instrumentation-System), it adds a property to `InstrumentationSystem` that gives you back a `Tracer`. You can then use that tracer to start `Span`s. In an HTTP client you e.g.
should start a `Span` when sending the outgoing HTTP request:

```swift
func get(url: String, context: LoggingContext) {
  var request = HTTPRequest(url: url)

  // inject the request headers into the baggage as explained above

  // start a span for the outgoing request
  let tracer = InstrumentationSystem.tracer
  var span = tracer.startSpan(named: "HTTP GET", context: context, ofKind: .client)

  // set attributes on the span
  span.attributes.http.method = "GET"
  // ...

  self.execute(request).always { _ in
    // set some more attributes & potentially record an error

    // end the span
    span.end()
  }
}
```

> ⚠️ Make sure to ALWAYS end spans. Ensure that all paths taken by the code will result in ending the span.
> Make sure that error cases also set the error attribute and end the span.

> In the above example we used the semantic `http.method` attribute that gets exposed via the
`TracingOpenTelemetrySupport` library.

## Instrument developers: Creating an instrument

Creating an instrument means adopting the `Instrument` protocol (or `Tracer` in case you develop a tracer).
`Instrument` is part of the `Instrumentation` library & `Tracing` contains the `Tracer` protocol.

`Instrument` has two requirements:

1. A method to inject values inside a `LoggingContext` into a generic carrier (e.g. HTTP headers)
2. A method to extract values from a generic carrier (e.g. HTTP headers) and store them in a `LoggingContext`

The two methods will be called by instrumented libraries/frameworks at asynchronous boundaries, giving you a chance to
act on the provided information or to add additional information to be carried across these boundaries.

> Check out the [`Baggage` documentation](https://github.com/apple/swift-distributed-tracing-baggage) for more information on
how to retrieve values from the `LoggingContext` and how to set values on it.

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

var context = DefaultLoggingContext.topLevel(logger: ...)
context.baggage.traceID = "4bf92f3577b34da6a3ce929d0e0e4736"
print(context.baggage.traceID ?? "new trace id")
```