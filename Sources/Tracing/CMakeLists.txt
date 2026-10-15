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

add_library(Tracing
  "InstrumentationSystem+Tracing.swift"
  "NoOpTracer.swift"
  "SpanProtocol.swift"
  "Tracer.swift"
  "TracerProtocol+Legacy.swift"
  "TracerProtocol.swift"
  "TracingTime.swift"
  "WithTracer.swift"
)
add_library(SwiftDistributedTracing::Tracing ALIAS Tracing)
_swift_distributed_tracing_library(Tracing)
target_link_libraries(Tracing PUBLIC Instrumentation ServiceContextModule)
if(CMAKE_SYSTEM_NAME STREQUAL "WASI")
  target_link_libraries(Tracing PUBLIC _CWASI)
endif()
