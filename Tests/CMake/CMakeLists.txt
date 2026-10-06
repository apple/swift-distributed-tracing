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

cmake_minimum_required(VERSION 3.29)
project(CMakeConsumer LANGUAGES C Swift)
find_package(SwiftDistributedTracing CONFIG REQUIRED)
add_executable(CMakeConsumer main.swift)
target_link_libraries(CMakeConsumer PRIVATE SwiftDistributedTracing::Instrumentation SwiftDistributedTracing::Tracing SwiftDistributedTracing::InMemoryTracing)
enable_testing()
add_test(NAME CMakeConsumer COMMAND CMakeConsumer)
if(WIN32)
  set_tests_properties(CMakeConsumer PROPERTIES ENVIRONMENT_MODIFICATION
    "PATH=path_list_prepend:$<TARGET_FILE_DIR:SwiftDistributedTracing::InMemoryTracing>;PATH=path_list_prepend:$<TARGET_FILE_DIR:SwiftServiceContext::ServiceContextModule>")
endif()
