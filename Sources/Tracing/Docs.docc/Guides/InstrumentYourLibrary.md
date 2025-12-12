# Instrument Your Library or Framework

## Overview 

This guide is aimed at library and framework developers who wish to instrument their code using distributed tracing.

Doing so within a library may enable automatic trace propagation and is key to propagating trace information across distributed nodes, e.g. by instrumenting the HTTP client used by such system.

Other examples of libraries which would benefit _the most_ from being instrumented using distributed tracing include:

- HTTP Clients (e.g. AsyncHTTPClient),
- HTTP Servers (e.g. Vapor or Smoke),
- RPC systems (Swift gRPC or Swift's `DistributedActorSystem` implementations),
- database drivers (e.g. SQL or MongoDB clients),
- any other library which can emit meaningful span information about tasks it is performing.

The most important libraries to instrument are "edge" libraries, which serve to connect between systems, because
it is them who must inject and extract context metadata to enable distributed trace ``Span`` propagation.

Following those, any database or other complex library which may be able to emit useful information about its internals are
also good candidates to being instrumented. Note that libraries may do so optionally, or hide the "verboseness" of such traces
behind options, or only attach information if a ``Span`` is already active etc. Please review your library's documentation to learn
more about it has integrated tracing support.

### Propagating context metadata

When crossing boundaries between processes, such as making or receiving an HTTP request, the library responsible for doing so should invoke instrumentation in order to inject or extract the context metadata into/from the "carrier" type (such as the `HTTPResponse`) type.

#### Handling outbound requests

When a library makes an "outgoing" request or message interaction, it should invoke the method of a configured instrument. This will invoke whichever instrument the end-user has configured and allow them to customize what metadata gets to be propagated. This can be depicted by the following diagram:

```
                        ┌──────────────────────────────────┐
                        │   Specific Tracer / Instrument   │
                        └──────────────────────────────────┘            
                                           │
   instrument.inject(context, into: request, using: httpInjector)   
                                           │                           
                                  ┌────────▼──────┐                             
                  ┌───────────────┤  Tracing API  ├────────────┐      ┌────┐
                  │HTTPClient     └────────▲──────┘            │      │ N  │
                  │                        │                   │      │ e  │
                  │ ┌───────────────┐   ┌──▼──────────────┐    │      │ t  │
┌───────────┐     │ |     make      │   │ add metadata to │    │      │ w  │
│ User code |────▶│ │  HTTPRequest  │──▶│   HTTPRequest   │────┼─────▶│ o  │
└───────────┘     │ └───────────────┘   └─────────────────┘    │      │ r  │
                  │                                            │      │ k  │
                  └────────────────────────────────────────────┘      └────┘
```

> Note: A library _itself_ cannot really know what information to propagate, since that depends on the used tracing or instrumentation system. The library does however understand its carrier type, and thus can implement the `Instrumentation/Injector` protocol.

For example, an HTTP client e.g. should inject the current context (which could be carrying trace ``Span`` information) into the HTTP headers as follows:

```swift
func get(url: String) -> HTTPResponse {
  var request = HTTPRequest(url: url)
  
  if let context = ServiceContext.current {
    InstrumentationSystem.instrument.inject(
      context,
      into: &request,
      using: HTTPRequestInjector()
    )
  }
  
  try await _send(request)
}
```

As you can see, the library does not know anything about what tracing system or instrumentation is installed, because it cannot know that ahead of time. 

All it has to do is query for the current [task-local](https://developer.apple.com/documentation/swift/tasklocal) `ServiceContext` value, and if one is present, call on the instrumentation system to inject it into the request.

Since neither the tracing API, nor the specific tracer backend are aware of this library's specific `HTTPRequest` type, we also need to implement an `Instrumentation/Injector` which takes on the responsibility of adding the metadata into the carrier type (which in our case is the `HTTPRequest`). An injector could for example be implemented like this:

```swift
struct HTTPRequestInjector: Injector {
    func inject(_ value: String, forKey key: String, into request: inout HTTPRequest) {
        request.headers.append((key, value))
    }
}
```

Once the metadata has been injected, the request--including all the additional metadata--is sent over the network.

> Note: The actual logic of deciding what context values to inject depend on the tracer implementation, and thus we are not covering it in this _end-user_ focused guide. Refer to <doc:ImplementATracer> if you'd like to learn about implementing a ``Tracer``.

#### Handling inbound requests

On the receiving side, an HTTP server needs to perform the inverse operation, as it receives the request from the network and forms an `HTTPRequest` object. Before it is passed it to user-code, it must extract any trace metadata from the request headers into the `ServiceContext`. 

```
                   ┌──────────────────────────────────┐
                   │   Specific Tracer / Instrument   │
                   └──────────────────────────────────┘
                                      ▲
                                      │
      instrument.extract(request, into: &context, using: httpExtractor)       
                                      │                                  
                               ┌──────▼──────┐                           
┌────┐          ┌──────────────┤ Tracing API ├────────────┐              
│ N  │          │HTTPServerLib └──────▲──────┘            │              
│ e  │          │                     │                   │              
│ t  │          │┌───────────────┐  ┌─▼───────────────┐   │              
│ w  │          ││     parse     │  │extract metadata │   │     ┌───────────┐
│ o  │─────────▶││  HTTPRequest  ├──▶from HTTPRequest │───┼────▶│ User code │
│ r  │          │└───────────────┘  └─────────────────┘   │     └───────────┘
│ k  │          │                                         │              
│    │          └─────────────────────────────────────────┘              
└────
```

This is very similar to what we were doing on the outbound side, but the roles of context and request are somewhat reversed: we're extracting values from the carrier into the context. The code performing this task could look something like this:

```swift
func handler(request: HTTPRequest) async {
  // we are beginning a new "top level" context - the beginning of a request - 
  // and thus start from a fresh, empty, top-level context:
  var context = ServiceContext.topLevel

  // populate the context by extracting interesting metadata from the incoming request:
  InstrumentationSystem.instrument.extract(
    request,
    into: &context,
    using: HTTPRequestExtractor()
  )

  // ... invoke user code ...
}
```

Similarly to the outbound side, we need to implement an `Instrumentation/Extractor` because the tracing libraries don't know about our specific HTTP types, yet we need to have them decide for which values to extract keys.

```swift
struct HTTPRequestExtract: Instrumentation.Extractor {
    func extract(key: String, from request: HTTPRequest) -> String? {
        request.headers.first(where: { $0.0 == key })?.1
    }
}
```

Which exact keys will be asked for depends on the tracer implementation, thus we don't present this part of the implementation in part of the guide. For example, a tracer most likely would look for, and extract, values for keys such as `trace-id` and `span-id`. Note though that the exact semantics and keys used by various tracers differ, which is why we have to leave the decision of what to extract up to tracer implementations.

Next, your library should "*restore*" the context, this is performed by setting the context task-local value around calling into user code, like this:

```swift
func handler(request: HTTPRequest) async {
  // ... 
  InstrumentationSystem.instrument.extract(..., into: &context, ...)
  // ... 

  // wrap user code with binding the ServiceContext task local:
  await ServiceContext.withValue(context) {
    await userCode(request)
  }

  // OR, alternatively start a span here - if your library should be starting spans on behalf of the user:
  // await startSpan("HTTP \(request.path)" { span in
  //  await userCode(request)
  // }
}
```

This sets the task-local value `ServiceContext.current` which is used by [swift-log](https://github.com/apple/swift-log), as well as ``Tracer`` APIs in order to later "*pick up*" the context and e.g. include it in log statements, or start new trace spans using the information stored in the context.

> Note: The end goal here being that when end-users of your library write `log.info("Hello")` the logger is able to pick up the context information and include the e.g. the `trace-id` in such log statement automatically! This way, every log made during the handling of this request would include the `trace-id` automatically, e.g. like this: 
>
> `12:43:32 info [trace-id=463a...13ad] Logging during handling of a request!`

If your library makes multiple calls to user-code as part of handling the same request, you may consider if restoring the context around all of these callbacks is beneficial. For example, if a library had callbacks such as:

```swift
/// Example library protocol, offering multiple callbacks, all semantically part of the same request handling.
protocol SampleHTTPHandler {
  // called immediately when an incoming HTTPRequests headers are available, 
  // even before the request body has been processed.
  func requestHeaders(headers: HTTPHeaders) async
  
  // Called multiple (or zero) times, for each "part" of the incoming HTTPRequest body.
  func requestBodyPart(ByteBuffer) async
}
```

You may want to restore the context once around both those calls, or if that is not possible, restore it every time when calling back into user code, e.g. like this:

```swift
actor MySampleServer { 
  
  var context: ServiceContext = .topLevel
  var userHandler: SampleHTTPHandler

  func onHeaders(headers: HTTPHeaders) async {
    await ServiceContext.withValue(self.context) { 
      await userHandler.requestHeaders(headers)
    }
  }
  
  func onBodyPart(part: ByteBuffer) async { 
    await ServiceContext.withValue(self.context) { 
      await userHandler.requestHeaders(headers)
    }
  }
}
```

While this code is very simple for illustration purposes, and it may seem surprising why there are two separate places where we need to call into user-code separately, in practice such situations can happen when using asynchronous network or database libraries which offer their API in terms of callbacks. Always consider if and when to restore context such that it makes sense for the end user.

#### Manual propogation

There are circumstances where [task-local variable](https://developer.apple.com/documentation/swift/tasklocal) propagation may be interrupted. One common instance is when using
[`swift-nio`](https://github.com/apple/swift-nio)'s [`EventLoopFuture`](https://swiftpackageindex.com/apple/swift-nio/main/documentation/niocore/eventloopfuture) to chain asynchronous work. In these circumstances, the library can manually propogate the context metadata by taking the context of the parent span, and providing it into the `context` argument of the child span:

```swift
// 1) start the parent span
withSpan("parent") { span in
  let parentContext = span.context

  // 2) start the child span, injecting the parent context
  withSpan("child", context: parentContext) { span in
    doSomething()
  }
}
```

Here's an example that uses Swift NIO's EventLoopFuture:

```swift
let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let parentSpan = startSpan("parent")
group.any().makeSucceededVoidFuture().map { _ in
  withSpan("child", context: parentSpan.context) { span in
    doSomething()
  }
}.always { _ in
  parentSpan.end()
}
```

### Starting Trace Spans in Your Library

The above steps are enough if you wanted to provide context propagation. It already enables techniques such as **correlation ids** which can be set once, in one system, and then carried through to any downstream services the code makes calls from while the context is set.

Many libraries also have the opportunity to start trace spans themselves, on behalf of users, in pieces of the library that can provide useful insight in the behavior or the library in production. For example, the `HTTPServer` can start spans as soon as it begins handling HTTP requests, and this way provide a parent span to any spans the user-code would be creating itself. 

Let us revisit the previous sample `HTTPServer` which restored context around invoking the user-code, and further extend it to start a span including basic information about the `HTTPRequest` being handled:

```swift
// SUB-OPTIMAL EXAMPLE:
func handler(request: HTTPRequest) async { 
  // 1) extract trace information into context...
  InstrumentationSystem.instrument.extract(..., into: &context, ...)
  // ...
  
  // 2) restore context, using a task-local:
  await ServiceContext.withValue(context) {
    // 3) start span, using context (which may contain trace-ids already):
    await withSpan("\(request.path)") { span in 
      // 3.1) Set useful attributes:on the span:
      span.attributes["http.method"] = request.method
      // ... 
      // See also: Open Telemetry typed attributes in swift-distributed-tracing-extras
                                                                    
      // 4) user code will have the apropriate Span context restored:
      await userCode(request)
    }
  }
}
```

This is introducing multiple layers of nesting, and we have un-necessarily restored, picked-up, and restored the context again. In order to avoid this duplicate work, it is beneficial to use the ``withSpan(_:context:ofKind:at:function:file:line:_:)-8gw3v`` overload, which also accepts a `ServiceContext` as parameter, rather than picking it up from the task-local value:

```swift
// BETTER
func handler(request: HTTPRequest) async { 
  // 1) extract trace information into context: 
  InstrumentationSystem.instrument.extract(..., into: &context, ...)

  // 2) start span, passing the freshly extracted context explicitly:
  await withSpan("\(request.path)", context: context) { span in 
    // ... 
  }
}
```

This method will only restore the context once, after the tracer has had a chance to decide if this execution will be traced, and if so, setting its own trace and span identifiers. This way only one task-local access (set) is performed in this version of the code, which is preferable to the set/read/set that was performed previously.

#### Manual Span Lifetime Management

While the ``withSpan(_:context:ofKind:at:function:file:line:_:)-8gw3v`` API is preferable in most situations, it may not be possible to use when the lifetime of a span only terminates in yet another callback API. In such situations, it may be impossible to "wrap" the entire piece of code that would logically represent "the span" using a `withSpan(...) { ... }` call.

In such situations you can resort to using the ``startSpan(_:context:ofKind:at:function:file:line:)`` and ``Span/end()`` APIs explicitly. Those APIs can then be used like this:

```swift
// Callback heavy APIs may need to store and manage spans manually:
var span: Span? 

func startHandling(request: HTTPRequest) {
  self.span = startSpan("\(request.path)")
  
  userCode.handle(request)
}

func finishHandling(request: HTTPRequest, response: HTTPResponse) {
  // always end spans (!)
  span?.end() // ends and flushes the span
}
```

It is very important to _always_ end spans that are started, as attached resources may keep accumulating and lead to memory leaks or worse issues in tracing backends depending on their implementation.

The manual way of managing spans also means that error paths need to be treated with increased attention. This is something that `withSpan` APIs handle automatically, but we cannot rely on `withSpan` detecting an error thrown out of its body closure anymore when using the `startSpan`/`Span.end` APIs.

When an error is thrown, or if the span should be considered errored for some reason, you should invoke the ``Span/recordError(_:)`` method and pass an `Swift.Error` that should be recorded on the span. Since failed spans usually show up in very visually distinct ways, and are most often the first thing a developer inspecting an application using tracing is looking for, it is important to get error reporting right in your library. Here is a simple example how this might look like:

```swift
var span: any Span

func onError(error: Error) {
  span.recordError(error) // record the error, and...
  span.end() // end the span
}
```

It is worth noting that double-ending a span should be considered a programmer error, and tracer implementations are free to crash or otherwise report such problem. 

>  Note: The problem with finding a span that was ended in two places is that its lifecycle seems to be incorrectly managed, and therefore the span timing information is at risk of being incorrect.
>
> Please also take care to never `end()` a span that was created using `withSpan()`  APIs, because `withSpan` will automatically end the span when the closure returns.

#### Storing and restoring context across callbacks 

Note also since a `Span` contains a `ServiceContext`, you can also pass the span's context to any APIs which may need it, or even restore the context e.g. for loggers to pick it up while emitting log statements:

```swift
final class StatefulHandler {
    var span: any Span

    func startHandling(request: HTTPRequest) {
        self.span = InstrumentationSystem.tracer.startSpan("\(request.path)")
    }

    // callback, form other task, so we don't have the task-local information here anymore
    func onSomethingHappening(event: SomeEvent) {
        ServiceContext.withValue(span.context) { // restore task-local context
            // which allows the context to be used by loggers and tracers as usual again: 
            log.info("Event happened: \(event)")

            // since the context was restored here, the startSpan will pick it up,
            // and the "event-id" span will be a child of the "request.path" span we started before.
            withSpan("event-\(event.id)") { span in // new child span (child of self.span)
                // ... handle the event ...
            }
        }
    }
}
```

It is also possible to pass the context explicitly to `withSpan` or `startSpan`:

```swift
withSpan("event-\(event.id)", context: span.context) { span in
  // ... 
}
```

which is equivalent to surrounding the `withSpan` call with a binding of the context. The passed context (with the values updated by the tracer), will then be set for the duration of the `withSpan` operation, just like usual.

### Global vs. "Stored" Tracers and Instruments

Tracing works similarly to swift-log and swift-metrics, in the sense that there is a global "backend" configured at application start, by end-users (developers) of an application. And this is how using `InstrumentationSystem/tracer` gets the "right" tracer at runtime.

You may be tempted to allow users _configuring_ a tracer as part of your applications initialization. Generally we advice against that pattern, because it makes it confusing which library needs to be configured, how, and where -- and if libraries are composed, perhaps the setting is not available to the actual "end-user" anymore.

On the other hand, it may be valuable for testing scenarios to be able to set a tracer on a specific instance of your library. Therefore, if you really want to offer a configurable `Instrument` or `Tracer` then we suggest defaulting this setting to `nil`, and if it is `nil`, reaching to the global `InstrumentationSystem/instrument` or `InstrumentationSystem/tracer` - this way it is possible to override a tracer for testing on a per-instance basis, but the default mode of operation that end-users expect from libraries remains working.
