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

cmake_minimum_required(VERSION 3.19)
project(SwiftDistributedTracing LANGUAGES C Swift)

if(CMAKE_SYSTEM_NAME STREQUAL "WASI")
  set(default_build_shared_libs NO)
else()
  set(default_build_shared_libs YES)
endif()
option(BUILD_SHARED_LIBS "Build shared libraries by default" ${default_build_shared_libs})

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
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules")
include(SwiftSupport)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lib")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lib")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/bin")
set(CMAKE_Swift_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/swift")

add_subdirectory(Sources)

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
