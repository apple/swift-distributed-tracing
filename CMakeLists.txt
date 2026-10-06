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
project(SwiftDistributedTracing LANGUAGES C Swift)

# Match the DLL runtime used by the Windows Swift SDK, including Debug builds.
if(WIN32 AND NOT DEFINED CMAKE_MSVC_RUNTIME_LIBRARY)
  set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreadedDLL)
endif()

if(CMAKE_Swift_COMPILER_VERSION VERSION_LESS 6.2)
  message(FATAL_ERROR "Swift 6.2 or newer is required")
endif()
if(WIN32 AND BUILD_SHARED_LIBS AND CMAKE_C_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
  message(FATAL_ERROR
    "Swift shared-library builds require Clang's GNU-style driver on Windows. Configure with -DCMAKE_C_COMPILER=clang.")
endif()
set(CMAKE_Swift_LANGUAGE_VERSION 6)
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)
include(cmake/SwiftLibrary.cmake)

if(TARGET SwiftServiceContext::ServiceContextModule)
  set(service_context_target SwiftServiceContext::ServiceContextModule)
elseif(TARGET ServiceContextModule)
  set(service_context_target ServiceContextModule)
else()
  find_package(SwiftServiceContext CONFIG REQUIRED)
  set(service_context_target SwiftServiceContext::ServiceContextModule)
endif()

add_library(Instrumentation
  Sources/Instrumentation/Locks.swift
  Sources/Instrumentation/NoOpInstrument.swift
  Sources/Instrumentation/MultiplexInstrument.swift
  Sources/Instrumentation/InstrumentationSystem.swift
  Sources/Instrumentation/Instrument.swift
)
add_library(SwiftDistributedTracing::Instrumentation ALIAS Instrumentation)
_swift_distributed_tracing_library(Instrumentation)
target_link_libraries(Instrumentation PUBLIC ${service_context_target})

add_library(Tracing
  Sources/Tracing/TracerProtocol+Legacy.swift
  Sources/Tracing/Tracer.swift
  Sources/Tracing/TracingTime.swift
  Sources/Tracing/TracerProtocol.swift
  Sources/Tracing/SpanProtocol.swift
  Sources/Tracing/InstrumentationSystem+Tracing.swift
  Sources/Tracing/WithTracer.swift
  Sources/Tracing/NoOpTracer.swift
)
add_library(SwiftDistributedTracing::Tracing ALIAS Tracing)
_swift_distributed_tracing_library(Tracing)
target_link_libraries(Tracing PUBLIC Instrumentation ${service_context_target})

add_library(InMemoryTracing
  Sources/InMemoryTracing/InMemorySpan.swift
  Sources/InMemoryTracing/InMemorySpanContext.swift
  Sources/InMemoryTracing/InMemoryTracer.swift
)
add_library(SwiftDistributedTracing::InMemoryTracing ALIAS InMemoryTracing)
_swift_distributed_tracing_library(InMemoryTracing)
target_link_libraries(InMemoryTracing PUBLIC Tracing)

if(CMAKE_SYSTEM_NAME STREQUAL "WASI")
  add_library(_CWASI Sources/_CWASI/_CWASI.c)
  target_include_directories(_CWASI PUBLIC
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/Sources/_CWASI/include>"
    "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/_CWASI>")
  configure_file(Sources/_CWASI/include/_CWASI.h
    "${CMAKE_CURRENT_BINARY_DIR}/wasi/_CWASI.h" COPYONLY)
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/wasi/module.modulemap"
    "module _CWASI { header \"_CWASI.h\" export * }\n")
  target_include_directories(_CWASI PUBLIC
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/wasi>")
  target_link_libraries(Tracing PUBLIC _CWASI)
  install(FILES "${CMAKE_CURRENT_BINARY_DIR}/wasi/module.modulemap"
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/_CWASI")
  install(TARGETS _CWASI EXPORT SwiftDistributedTracingTargets)
  install(DIRECTORY Sources/_CWASI/include/ DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/_CWASI")
endif()

set(package_directory "${CMAKE_INSTALL_LIBDIR}/cmake/SwiftDistributedTracing")
configure_package_config_file(cmake/SwiftDistributedTracingConfig.cmake.in
  "${CMAKE_CURRENT_BINARY_DIR}/SwiftDistributedTracingConfig.cmake"
  INSTALL_DESTINATION "${package_directory}")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/SwiftDistributedTracingConfig.cmake"
  DESTINATION "${package_directory}")
install(EXPORT SwiftDistributedTracingTargets NAMESPACE SwiftDistributedTracing::
  DESTINATION "${package_directory}")
export(EXPORT SwiftDistributedTracingTargets NAMESPACE SwiftDistributedTracing::
  FILE "${CMAKE_CURRENT_BINARY_DIR}/SwiftDistributedTracingTargets.cmake")
