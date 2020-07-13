# Swift (Server) Tracing

[![Swift 5.2](https://img.shields.io/badge/Swift-5.2-ED523F.svg?style=flat)](https://swift.org/download/)
[![CI](https://github.com/slashmo/gsoc-swift-tracing/workflows/CI/badge.svg)](https://github.com/slashmo/gsoc-swift-tracing/actions?query=workflow%3ACI)

This is a WIP collection of Swift libraries enabling Tracing for your Swift (Server) systems. Check out the [GSoC project overview](https://summerofcode.withgoogle.com/projects/#6092707967008768) to learn more. For a more detailed project plan please take a look [at this Google doc](https://docs.google.com/document/d/19j9x515dR0IAwF3Zoevxoj6jvMdGpP4UuyGhmEXO_B8).

## Dependencies

The Swift packages contained in this repository make use of the library package `Baggage`, which can be found in a separate repository: https://github.com/slashmo/gsoc-swift-baggage-context

## Discussions

Discussions about this topic are **more than welcome**. During this project we'll use a mixture of [GitHub issues](https://github.com/slashmo/gsoc-swift-tracing/issues) and [Swift forum posts](https://forums.swift.org/c/server/serverdev/14).

## Contributing

Please make sure to run the `./scripts/sanity.sh` script when contributing, it checks formatting and similar things.

You can make ensure it always is run and passes before you push by installing a pre-push hook with git:

```
echo './scripts/sanity.sh' > .git/hooks/pre-push
```
