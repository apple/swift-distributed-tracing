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

add_library(Instrumentation
  "Instrument.swift"
  "InstrumentationContext.swift"
  "InstrumentationContextKey.swift"
  "InstrumentationSystem.swift"
  "Locks.swift"
  "MultiplexInstrument.swift"
  "NoOpInstrument.swift"
)
add_library(SwiftDistributedTracing::Instrumentation ALIAS Instrumentation)
_swift_distributed_tracing_library(Instrumentation)
