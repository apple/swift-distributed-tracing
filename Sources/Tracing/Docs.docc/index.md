# ``/Tracing``

A Distributed Tracing API for Swift.

## Overview

This is a collection of Swift libraries enabling the instrumentation of server side applications using tools such as tracers. Our goal is to provide a common foundation that allows to freely choose how to instrument systems with minimal changes to your actual code.

While Swift Distributed Tracing allows building all kinds of _instruments_, which can co-exist in applications transparently, its primary use is instrumenting multithreaded and distributed systems with _distributed traces_.

### Quickstart Guides

We provide a number of guides aimed at getting started with tracing your systems, and have prepared them from three "angles":

1. <doc:TraceYourApplication>, for **Application developers** who create server-side applications, 
2. <doc:InstrumentYourLibrary>, for **Library/Framework developers** who provide building blocks to create these applications, 
3. <doc:ImplementATracer>, for **Instrument developers** who provide tools to collect distributed metadata about your application.

If unsure where to start, we recommend starting at the first guide and continue reading until satisfied, 
as the subsequent guides dive deeper into patterns and details of instrumenting systems and building instruments yourself.

## Topics

### Guides

- <doc:TraceYourApplication>
- <doc:InstrumentYourLibrary>
- <doc:ImplementATracer>

### Boostrapping Tracing

- ``Tracing/Instrumentation/InstrumentationSystem``
- ``Tracing/Tracer``
- ``TracerInstant``
- ``LegacyTracer``

### Creating Spans

- ``withSpan(_:context:ofKind:function:file:line:_:)-65bom``
- ``withSpan(_:at:context:ofKind:function:file:line:_:)-7pdo8``
- ``withSpan(_:context:ofKind:isolation:function:file:line:_:)``
- ``withSpan(_:at:context:ofKind:isolation:function:file:line:_:)``
- ``withSpan(_:context:ofKind:at:function:file:line:_:)-6e2id``
- ``withSpan(_:context:ofKind:at:isolation:function:file:line:_:)``

- ``withSpan(_:context:ofKind:function:file:line:_:)-tj8``
- ``withSpan(_:at:context:ofKind:function:file:line:_:)-3h6gv``
- ``withSpan(_:context:ofKind:at:function:file:line:_:)-8gw3v``

### Manually Managing Spans

- ``startSpan(_:context:ofKind:function:file:line:)``
- ``startSpan(_:at:context:ofKind:function:file:line:)``
- ``startSpan(_:context:ofKind:at:function:file:line:)``
- ``Span/end()``

### Inspecting Spans

- ``Span``
- ``SpanAttributeConvertible``
- ``SpanAttributeNamespace``
- ``NestedSpanAttributesProtocol``
- ``SpanAttributes``
- ``SpanAttributeKey``
- ``SpanAttribute``
- ``SpanEvent``
- ``SpanLink``
- ``SpanStatus``
- ``SpanKind``

### Default Tracers

- ``DefaultTracerClock``
- ``NoOpTracer``
