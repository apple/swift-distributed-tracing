# ``SwiftDistributedTracing``

A Distributed Tracing API for Swift.

## Overview

This is a collection of Swift libraries enabling the instrumentation of server side applications using tools such as tracers. Our goal is to provide a common foundation that allows to freely choose how to instrument systems with minimal changes to your actual code.

While Swift Distributed Tracing allows building all kinds of _instruments_, which can co-exist in applications transparently, its primary use is instrumenting multi-threaded and distributed systems with Distributed Traces.

### Quickstart Guides

We provide a number of guides aimed at getting your started with tracing your systems and have prepared them from three "angles":

1. **Application developers** who create server-side applications
    * please refer to the <doc:TraceYourApplication> guide.
2. **Library/Framework developers** who provide building blocks to create these applications
    * please refer to the <doc:InstrumentYourLibrary> guide. 
3. **Instrument developers** who provide tools to collect distributed metadata about your application
    * please refer to the <doc:ImplementATracer> guide.


## Topics

### Guides

- <doc:TraceYourApplication>
- <doc:InstrumentYourLibrary>
- <doc:ImplementATracer>
