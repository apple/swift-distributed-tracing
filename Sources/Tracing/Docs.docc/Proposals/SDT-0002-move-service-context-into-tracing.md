# SDT-0002: move `ServiceContext` to swift-distributed-tracing

Move the `ServiceContext` implementation into swift-distributed-tracing, rename `ServiceContext`,
`ServiceContextKey`, and `AnyServiceContextKey` to `TracingContext`, `TracingContextKey`, and
`AnyTracingContextKey`, and keep swift-service-context as a thin, unaffected compatibility package.

## Overview

- Proposal: SDT-0002
- Author(s): [Vladimir Kukushkin](https://github.com/kukushechkin)
- Status: **Awaiting Review**
- Issue: TBA
- Implementation: TBA
- Related links:
    - [Lightweight proposals process description](https://github.com/apple/swift-distributed-tracing/blob/main/Sources/Tracing/Docs.docc/Proposals/Proposals.md)

### Introduction

This proposal moves `ServiceContext` and its supporting types out of the swift-service-context package into
a new `ContextStorage` target inside swift-distributed-tracing, and renames the types themselves:
`ServiceContext` to `TracingContext`, `ServiceContextKey` to `TracingContextKey`, and
`AnyServiceContextKey` to `AnyTracingContextKey`. All three old names stay available everywhere as
typealiases.

### Motivation

Most adopters reach `ServiceContextModule` only through `Tracing`, not as a direct dependency, so the
two-package split mostly adds release latency for a type whose main consumer is one package.

`ServiceContext` also reads as Swift Server specific. In practice it carries any ambient, propagated state,
not just service-to-service request state, and the name has stopped people from adopting
swift-distributed-tracing outside server applications.

### Proposed solution

Move `ServiceContext`, `ServiceContextKey`, `AnyServiceContextKey`, and `TODOLocation` out of
swift-service-context's `ServiceContextModule` into a new `ContextStorage` target in
swift-distributed-tracing, and rename three of them:

- `ServiceContext` becomes `TracingContext`.
- `ServiceContextKey` becomes `TracingContextKey`.
- `AnyServiceContextKey` becomes `AnyTracingContextKey`.
- `TODOLocation` keeps its name.

### Detailed design

New types, in swift-distributed-tracing's `ContextStorage` target:

```swift
public struct TracingContext: Sendable { ... }
public protocol TracingContextKey: Sendable { ... }
public struct AnyTracingContextKey: Sendable { ... }
```

`TODOLocation` moves into `ContextStorage` unchanged.

New typealiases, deprecated, also in `ContextStorage`:

```swift
@available(*, deprecated, renamed: "TracingContext")
public typealias ServiceContext = TracingContext

@available(*, deprecated, renamed: "TracingContextKey")
public typealias ServiceContextKey = TracingContextKey

@available(*, deprecated, renamed: "AnyTracingContextKey")
public typealias AnyServiceContextKey = AnyTracingContextKey
```

New typealiases, not deprecated, in swift-service-context's `ServiceContextModule`:

```swift
@_exported import ContextStorage

public typealias ServiceContext = ContextStorage.TracingContext
public typealias ServiceContextKey = ContextStorage.TracingContextKey
public typealias AnyServiceContextKey = ContextStorage.AnyTracingContextKey
```

### API stability

Source-compatible everywhere: `import Tracing`, `import ServiceContextModule`, and
`import InstrumentationBaggage` keep compiling unchanged.

- Old names used directly through swift-distributed-tracing (`import Tracing` or `ContextStorage`) get a
  deprecation warning, including at a `ServiceContextKey` conformance clause.
- Old names used through `ServiceContextModule` get no warning: its own declarations shadow the deprecated
  ones re-exported from `ContextStorage`, even when a file imports both at once.
- An adopter of only swift-distributed-tracing stops resolving swift-service-context.
- An adopter of only swift-service-context now also resolves the full swift-distributed-tracing package,
  though the build only compiles `ContextStorage`.
- A file that imports `ServiceContextModule` without declaring swift-service-context, relying on it being
  present only transitively through swift-distributed-tracing, loses the module.
- Upgrading only one of the two packages, so an old swift-service-context and a new
  swift-distributed-tracing resolve together, fails to build: `ambiguous use of 'ServiceContext'`.

### Future directions

The ServiceContext API primarily exists to enable the "copy values of which you don't even know about" to
continue the context's entire ambient context. Ever since it was first introduced, task locals in Swift
became the predominant way of handling ambient context following the task structure, they do lack one
crucial API however — the ability to copy "all" task local values into a new context, which may be e.g.
then invoked from a callback or similar.

This functionality exists in the Swift runtime, and is utilized by the `Task.init` initializer, which does
copy all values into a new context (unlike `Task.detached` which does not). We could consider exposing this
functionality to all task locals, making the need for a general purpose context object not necessary
anymore — this follows nicely from making this context type a tracing specific thing, rather than claiming
it is a general purpose context object.

### Alternatives considered

**Keep the two packages as they are.** Keeps `ServiceContextModule` a zero-dependency package for adopters
who want context propagation without tracing.
