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

set(package_directory "${CMAKE_INSTALL_LIBDIR}/cmake/SwiftDistributedTracing")
configure_package_config_file(SwiftDistributedTracingConfig.cmake.in
  "${CMAKE_CURRENT_BINARY_DIR}/SwiftDistributedTracingConfig.cmake"
  INSTALL_DESTINATION "${package_directory}")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/SwiftDistributedTracingConfig.cmake"
  DESTINATION "${package_directory}")
install(EXPORT SwiftDistributedTracingTargets NAMESPACE SwiftDistributedTracing::
  DESTINATION "${package_directory}")
export(EXPORT SwiftDistributedTracingTargets NAMESPACE SwiftDistributedTracing::
  FILE "${CMAKE_CURRENT_BINARY_DIR}/SwiftDistributedTracingTargets.cmake")
