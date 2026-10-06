# Building with CMake

CMake 3.29 or newer, Ninja, and Swift 6.2 or newer are required. Ninja Multi-Config
requires CMake 4.0 or newer. SwiftPM remains the test runner for the Swift unit tests.

On Windows, run CMake from a Visual Studio developer command prompt so the MSVC
linker and Windows SDK are available. Add `-DCMAKE_C_COMPILER=clang` to each configure
command to use the Clang driver supplied with Swift. Shared builds require this
GNU-style driver because CMake's MSVC C driver initializes linker flags that Swift
cannot consume directly. Use the same build configuration for libraries and their
consumer. The default Windows runtime is `MultiThreadedDLL` to match Swift's SDK;
set `-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL` in independent consumers too.

Configure, build, and install the libraries:

```sh
# First build and install swift-service-context with its CMake support.
cmake -S . -B build -G Ninja -DCMAKE_PREFIX_PATH=/path/to/context/install -DCMAKE_INSTALL_PREFIX=/path/to/install
cmake --build build
cmake --install build
```

Pass `-DBUILD_SHARED_LIBS=ON` to build shared libraries. An enclosing CMake project
can also use `add_subdirectory` and link the namespaced targets. The build directory
and install prefix both provide a `SwiftDistributedTracing` package configuration.

The independent consumer verifies that public modules can be imported and linked:

```sh
cmake -S Tests/CMake -B consumer -G Ninja -DCMAKE_PREFIX_PATH="/path/to/install;/path/to/context/install"
cmake --build consumer
ctest --test-dir consumer --output-on-failure
```

For Tracing's consumer, include both dependency installation prefixes in
`CMAKE_PREFIX_PATH` if Service Context is installed separately. Test relocated
installations by moving the installation prefix before configuring the consumer.
For Ninja Multi-Config, pass `--config Debug` to build/install and `-C Debug` to CTest.
