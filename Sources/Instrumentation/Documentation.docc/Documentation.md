# ``Instrumentation``

Base set of types which can be used to instrument libraries, excluding tracing support. Instrument implementations can be used to extract or inject contextual metadata from carrier objects (such as http requests, messages, or similar), and can be used for context propagation across process boundaries, or enrichment of contextual data, such as injecting/extracting "authorized user" or similar metadata.

## Overview

``InstrumentationContext`` is a minimal context propagation container, intended to "carry" context items for
purposes of cross-cutting tools to be built on top of it.

It is modeled after the concepts explained in [W3C Baggage](https://w3c.github.io/baggage/) and the
in the spirit of [Tracing Plane](https://cs.brown.edu/~jcmace/papers/mace18universal.pdf)'s "Baggage Context" type,
although by itself it doesn't define a specific serialization format.

This module is the implementation home for ``InstrumentationContext``. Most code should not depend on it
directly: depend on `Tracing` if you need spans, or on the `ServiceContextModule` product of the
`swift-service-context` package if you only need context propagation without tracing. Both re-export the
exact same `InstrumentationContext` type defined here. This package also keeps a deprecated `ServiceContext`
alias, the type's former name.

> Note: Automatic propagation through task-locals by using `InstrumentationContext.current` is supported in
> Swift version 5.5 or later.

## Topics

### Instruments

- ``InstrumentationSystem``
- ``MultiplexInstrument``
- ``NoOpInstrument``
- ``Instrument``
- ``Extractor``
- ``Injector``

### Context Propagation

- ``InstrumentationContext``
- ``InstrumentationContextKey``
- ``AnyInstrumentationContextKey``
- ``TODOLocation``
