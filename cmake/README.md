# Building with CMake

CMake 3.19 or newer, Ninja, and Swift 6.2 or newer are required. SwiftPM remains the test runner for the Swift unit tests.

On Windows, run CMake from a Visual Studio developer command prompt so the MSVC
linker and Windows SDK are available. Add `-DCMAKE_C_COMPILER=clang` to each configure
command to use the Clang driver supplied with Swift. Shared builds require this
GNU-style driver because CMake's MSVC C driver initializes linker flags that Swift
cannot consume directly. Use the same build configuration for libraries and their
consumer. The default Windows runtime is `MultiThreadedDLL` to match Swift's SDK;
set `-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL` in independent consumers too.

Configure, build, and install the libraries:

```sh
cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/path/to/install
cmake --build build
cmake --install build
```

Shared libraries are built by default, matching Swift Log and Swift Metrics.
Pass `-DBUILD_SHARED_LIBS=OFF` to build static libraries. The re-export-only
ServiceContextModule shim remains a static archive. An enclosing CMake project
can also use `add_subdirectory` and link the namespaced targets. The build directory
and install prefix both provide a `SwiftDistributedTracing` package configuration.

Instrumentation owns the context types. The package also exports
`SwiftDistributedTracing::ServiceContextModule` for compatibility with existing
Service Context imports, matching the SwiftPM target graph. No separate Service
Context installation is required.

Targets are declared in `Sources/<target>/CMakeLists.txt`. Build artifacts use
`lib`, `bin`, and `swift` directories. Installed Swift modules follow the Swift
Log and Swift Metrics layout under `lib/swift/<platform>` for shared libraries
and `lib/swift_static/<platform>` for static libraries, with target triples in
each module directory. Package configuration files are defined in `cmake/modules`,
matching the Swift Log layout. Ninja is the supported generator.
