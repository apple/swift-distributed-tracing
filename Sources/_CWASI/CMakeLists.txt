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

add_library(_CWASI
  "_CWASI.c"
)
target_include_directories(_CWASI PUBLIC
  "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
  "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/_CWASI>")
configure_file(include/_CWASI.h
  "${CMAKE_CURRENT_BINARY_DIR}/wasi/_CWASI.h" COPYONLY)
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/wasi/module.modulemap"
  "module _CWASI { header \"_CWASI.h\" export * }\n")
target_include_directories(_CWASI PUBLIC
  "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/wasi>")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/wasi/module.modulemap"
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/_CWASI")
install(TARGETS _CWASI EXPORT SwiftDistributedTracingTargets)
install(DIRECTORY include/ DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/_CWASI")
