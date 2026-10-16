# Test suite

`test/c/` holds the ctest suite: one executable per kernel, each registered with ctest.
`test/c/check.h` is a dependency-free assertion helper that exits non-zero on failure.
`test/python/` holds the pytest suite. With `DIANA_BUILD_TEST=ON` (outside scikit-build), ctest also
installs the build into `<build>/install-test` (test `install`) and builds and runs the consumer
project `test/install/` against it with `find_package(diana)` (test `find_package`); the consumer is
linked with the parent's `CMAKE_EXE_LINKER_FLAGS` for coverage builds; sanitizer runtime options
come from the installed target. On macOS, the consumer inherits the configured architecture
list, SDK, and deployment target, including universal builds.

The pytest suite also checks the spec gate with temporary spec and expectation files and mocked
prover execution. The `test` dependency group includes PyYAML for those checks.

`uv run script/check_wheel.py` builds static and shared wheels in separate temporary directories,
checks their runtime-library contents and absence of development artifacts, removes their build
trees, and installs each into a fresh uv virtual environment. An isolated Python process outside
the checkout imports Diana and checks bisection of `x*x - 2`, with loader-path overrides removed.
This tests the installed wheel without relying on the development environment or build RPATHs.

ctest also runs the driver of the [compiler comparison](../verification/compiler.md) as the
`compiler` test.

The expected values of each kernel's tests are explained per method: [bisection](bisection.md),
[composite trapezoidal rule](trapezoidal.md), [composite Simpson rule](simpson.md), and
[explicit Euler step](euler.md).
