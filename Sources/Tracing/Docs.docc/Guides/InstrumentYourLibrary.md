# Instrument Your Library or Framework

## Overview 

This guide is aimed at library and framework developers who wish to instrument their code using distributed tracing.

Doing so within a library may enable automatic trace propagation and is key to propagating trace information across
distributed nodes, e.g. by instrumenting the HTTP client used by such system.

Other examples of libraries which benefit _the most_ from being instrumented using distributed tracing include:

- HTTP Clients (e.g. AsyncHTTPClient),
- HTTP Servers (e.g. Vapor or Smoke),
- RPC systems (Swift gRPC or Swift's `DistributedActorSystem` implementations),
- database drivers (e.g. SQL or MongoDB clients),
- any other library which can emit meaningful span information about tasks it is performing.

The most important libraries to instrument are "edge" libraries, which serve to connect between systems, because
it is them who must inject and extract contextual baggage metadata to enable distributed trace ``Span`` propagation.

Following those, any database or other complex library which may be able to emit useful information about its internals are
also good candidates to being instrumented. Note that libraries may do so optionally, or hide the "verboseness" of such traces
behind options, or only attach information if a Span is already active etc. Please review your library's documentation to learn
more about it has integrated tracing support.

### Extracting & injecting Baggage

When hitting boundaries like an outgoing HTTP request you call out to the configured instrument(s) (see <doc:InDepthGuide#Bootstrapping-the-InstrumentationSystem>):

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

In order to work with the tracer configured by the end-user (see <doc:InDepthGuide#Bootstrapping-the-InstrumentationSystem>), it adds a property to `InstrumentationSystem` that gives you back a ``Tracer``. You can then use that tracer to start ``Span``s. In an HTTP client you e.g.
should start a ``Span`` when sending the outgoing HTTP request:

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


