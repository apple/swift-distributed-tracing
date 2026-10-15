##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift Distributed Tracing open source project
##
## Copyright (c) 2026 Apple Inc. and the Swift Distributed Tracing project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of Swift Distributed Tracing project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

add_library(InMemoryTracing
  "InMemorySpan.swift"
  "InMemorySpanContext.swift"
  "InMemoryTracer.swift"
)
add_library(SwiftDistributedTracing::InMemoryTracing ALIAS InMemoryTracing)
_swift_distributed_tracing_library(InMemoryTracing)
target_link_libraries(InMemoryTracing PUBLIC Tracing)
