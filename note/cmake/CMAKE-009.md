---
id: CMAKE-009
title: Installed CMake package layout
kind: fact
path:
  - CMakeLists.txt
  - cmake/dianaConfig.cmake.in
  - test/install/CMakeLists.txt
  - test/install/main.c
related: [CMAKE-006, CMAKE-008, CMAKE-004]
---
Outside scikit-build, `cmake --install` installs the library, the headers and a CMake package
whose paths all follow `GNUInstallDirs`.

- `include(GNUInstallDirs)` comes before the target is defined, so `CMAKE_INSTALL_INCLUDEDIR`
  sets both the header destination (`include/diana` is copied there) and the exported include
  path (`$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>`).
- The library goes to `CMAKE_INSTALL_LIBDIR`, with `VERSION` = the project version and
  `SOVERSION` = its major version (set only when `SKBUILD` is not defined).
- `dianaTargets.cmake` (namespace `diana::`), `dianaConfig.cmake` and `dianaConfigVersion.cmake`
  (`SameMinorVersion`) go to `${CMAKE_INSTALL_LIBDIR}/cmake/diana`.
- With `DIANA_BUILD_TEST=ON`, ctest `install` installs the build tree into `install-test/` and
  `find_package` builds and runs `test/install/` against it, forwarding the C compiler, build
  type, `CMAKE_EXE_LINKER_FLAGS` and any `CMAKE_OSX_ARCHITECTURES`, `CMAKE_OSX_SYSROOT` and
  `CMAKE_OSX_DEPLOYMENT_TARGET`.
- CI job `test_install` runs those tests with `-DCMAKE_INSTALL_INCLUDEDIR=include/custom` and,
  separately, with `-DDIANA_BUILD_SHARED_LIB=ON`.
