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

add_subdirectory(Instrumentation)
add_subdirectory(ServiceContextModule)
if(CMAKE_SYSTEM_NAME STREQUAL "WASI")
  add_subdirectory(_CWASI)
endif()
add_subdirectory(Tracing)
add_subdirectory(InMemoryTracing)
