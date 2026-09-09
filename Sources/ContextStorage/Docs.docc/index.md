# ``ContextStorage``

Common currency type for type-safe and Swift concurrency aware context propagation.

## Overview

``TracingContext`` is a minimal (zero-dependency) context propagation container, intended to "carry" context
items for purposes of cross-cutting tools to be built on top of it.

It is modeled after the concepts explained in [W3C Baggage](https://w3c.github.io/baggage/) and the
in the spirit of [Tracing Plane](https://cs.brown.edu/~jcmace/papers/mace18universal.pdf)'s "Baggage Context" type,
although by itself it doesn't define a specific serialization format.

This module is the implementation home for ``TracingContext``. Most code should not depend on it directly:
depend on `Tracing` if you need spans, or on the `ServiceContextModule` product of the `swift-service-context`
package if you only need context propagation without tracing. Both re-export the exact same `TracingContext`
type defined here. This package also keeps a deprecated `ServiceContext` alias, the type's former name.

> Note: Automatic propagation through task-locals by using `TracingContext.current` is supported in Swift
> version 5.5 or later.

## Topics

- ``TracingContext``
- ``TracingContextKey``
- ``AnyTracingContextKey``
- ``TODOLocation``
