---
id: TEST-002
title: ctest installs the build and builds a find_package consumer against it
kind: fact
path:
  - CMakeLists.txt
  - test/install/CMakeLists.txt
  - test/install/main.c
  - cmake/dianaConfig.cmake.in
related: [TEST-001, TEST-003, BUILD-002]
---
With `DIANA_BUILD_TEST=ON` outside scikit-build, ctest installs the build and then builds and runs
the separate project `test/install/` against the installed package, so the exported CMake package
is tested the way a user consumes it.

- Test `install` runs `cmake --install <build> --prefix <build>/install-test --config <config>`
  and sets up fixture `diana_install`.
- Test `find_package` requires that fixture and runs `ctest --build-and-test` from `test/install/`
  into `<build>/test/install` with the parent's generator, make program and configuration, then
  runs `consume`. Build options: `CMAKE_PREFIX_PATH=<build>/install-test`, the parent's
  `CMAKE_C_COMPILER` and `CMAKE_EXE_LINKER_FLAGS` (so a `--coverage` build, as in `coverage_c`,
  links its instrumented library), and `CMAKE_OSX_ARCHITECTURES`, `CMAKE_OSX_SYSROOT` and
  `CMAKE_OSX_DEPLOYMENT_TARGET` when defined, with `;` escaped so a universal architecture list
  survives.
- No sanitizer option is passed: with `DIANA_SANITIZER=ON` the `diana` target has the `PUBLIC`
  link option `-fsanitize=address,undefined`, which the installed `dianaTargets` export hands to
  the consumer.
- `test/install/CMakeLists.txt` calls `find_package(diana 1.0 CONFIG REQUIRED)` and links
  `diana::diana`. The version file uses `SameMajorVersion`, so only a major version bump fails this
  test until the requested version is raised (the `doc/api` CMake example is checked separately,
  TEST-003).
- `test/install/main.c` solves `x*x - 2` on `[0, 2]` with `diana_bisection` (`tol = 1e-12`, 100
  steps), checks the root to `1e-12` and that `diana_version()` equals the header's
  `DIANA_VERSION_STRING`, and prints `find_package(diana): ok`.
- CI `test_install` runs the whole ctest suite, these two tests included, on two fresh Release
  builds: one with `CMAKE_INSTALL_INCLUDEDIR=include/custom`, one with `DIANA_BUILD_SHARED_LIB=ON`.
