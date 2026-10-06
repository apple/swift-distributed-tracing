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

function(_swift_distributed_tracing_library target)
  set(module_directory "${CMAKE_CURRENT_BINARY_DIR}/swift")
  if(CMAKE_CONFIGURATION_TYPES)
    foreach(configuration IN LISTS CMAKE_CONFIGURATION_TYPES)
      file(MAKE_DIRECTORY "${module_directory}/${configuration}")
    endforeach()
    set(module_directory "${module_directory}/$<CONFIG>")
    if(CMAKE_VERSION VERSION_LESS 4.0)
      message(FATAL_ERROR "Swift multi-configuration builds require CMake 4.0 or newer")
    endif()
  endif()
  set_target_properties(${target} PROPERTIES
    Swift_MODULE_DIRECTORY "${module_directory}"
    POSITION_INDEPENDENT_CODE YES)
  target_compile_options(${target} PRIVATE
    "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-package-name swift_distributed_tracing>"
    "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-enable-experimental-feature StrictConcurrency=complete>")
  target_include_directories(${target} PUBLIC
    "$<BUILD_INTERFACE:${module_directory}>"
    "$<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/swift>")
  install(TARGETS ${target} EXPORT SwiftDistributedTracingTargets)
  install(FILES
    "${module_directory}/${target}.swiftmodule"
    "${module_directory}/${target}.swiftdoc"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/swift")
endfunction()
