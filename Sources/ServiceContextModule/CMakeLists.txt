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

# This re-export-only module has no symbols to produce a Windows DLL import library.
add_library(ServiceContextModule STATIC
  "ServiceContextModule.swift"
)
add_library(SwiftDistributedTracing::ServiceContextModule ALIAS ServiceContextModule)
_swift_distributed_tracing_library(ServiceContextModule)
target_link_libraries(ServiceContextModule PUBLIC Instrumentation)
