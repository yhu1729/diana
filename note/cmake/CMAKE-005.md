---
id: CMAKE-005
title: DIANA_BUILD_SHARED_LIB instead of BUILD_SHARED_LIBS
kind: rationale
path:
  - CMakeLists.txt
related: [CMAKE-002, CMAKE-004]
---
The library type comes from the project's own option `DIANA_BUILD_SHARED_LIB` (default OFF),
passed explicitly as `add_library(diana SHARED|STATIC ...)`, and never from the generic
`BUILD_SHARED_LIBS`.

The generic variable is global: an enclosing project that adds Diana with `add_subdirectory`, or
a command line that sets it for other reasons, would silently switch Diana's library type. With an
explicit type argument CMake ignores `BUILD_SHARED_LIBS` for this target, so only a request
addressed to Diana changes it, and the wheel build chooses static or shared by
`cmake.define.DIANA_BUILD_SHARED_LIB` (CMAKE-004). The option was renamed from
`BUILD_SHARED_LIBS` (commit `75904e1`); the CI job `test_install` builds the shared variant with
`-DDIANA_BUILD_SHARED_LIB=ON`.
