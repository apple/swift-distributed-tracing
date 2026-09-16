# ``/Tracing``

A Distributed Tracing API for Swift.

## Overview

This is a collection of Swift libraries enabling the instrumentation of server side applications using tools such as tracers. Our goal is to provide a common foundation that allows to freely choose how to instrument systems with minimal changes to your actual code.

While Swift Distributed Tracing allows building all kinds of _instruments_, which can co-exist in applications transparently, its primary use is instrumenting multithreaded and distributed systems with _distributed traces_.

### Guides

We provide a number of guides aimed at getting started with tracing your systems, targeted at three
different audiences: application developers, library and framework developers, and instrument
implementers. See <doc:TraceYourApplication>, <doc:InstrumentYourLibrary>, and <doc:ImplementATracer>
below to find the guide for your role.

## Topics

### Quickstart guides

- <doc:TraceYourApplication>
- <doc:InstrumentYourLibrary>
- <doc:ImplementATracer>

### Boostrapping tracing

- ``Tracing/Instrumentation/InstrumentationSystem``
- ``Tracing/Tracer``
- ``TracerInstant``
- ``LegacyTracer``

### Scoping a tracer

- ``withTracer(_:_:)-28xx1``
- ``withTracer(_:_:)-mixl``

### Creating spans

- ``withSpan(_:context:ofKind:function:file:line:_:)-65bom``
- ``withSpan(_:at:context:ofKind:function:file:line:_:)-7pdo8``
- ``withSpan(_:context:ofKind:isolation:function:file:line:_:)``
- ``withSpan(_:at:context:ofKind:isolation:function:file:line:_:)``
- ``withSpan(_:context:ofKind:at:function:file:line:_:)-6e2id``
- ``withSpan(_:context:ofKind:at:isolation:function:file:line:_:)``

- ``withSpan(_:context:ofKind:function:file:line:_:)-tj8``
- ``withSpan(_:at:context:ofKind:function:file:line:_:)-3h6gv``
- ``withSpan(_:context:ofKind:at:function:file:line:_:)-8gw3v``

### Manually managing spans

- ``startSpan(_:context:ofKind:function:file:line:)``
- ``startSpan(_:at:context:ofKind:function:file:line:)``
- ``startSpan(_:context:ofKind:at:function:file:line:)``
- ``Span/end()``

### Inspecting spans

- ``Span``
- ``SpanEvent``
- ``SpanLink``
- ``SpanStatus``
- ``SpanKind``

### Span attributes

- ``SpanAttributeConvertible``
- ``SpanAttributeNamespace``
- ``NestedSpanAttributesProtocol``
- ``SpanAttributes``
- ``SpanAttributeKey``
- ``SpanAttribute``

### Default tracers

- ``DefaultTracerClock``
- ``NoOpTracer``

### Proposal process

- <doc:Proposals>
