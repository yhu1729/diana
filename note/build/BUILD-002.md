---
id: BUILD-002
title: CMake options and their defaults
kind: fact
path:
  - CMakeLists.txt
  - pyproject.toml
  - script/dev.sh
related: [BUILD-003, BUILD-005, BUILD-007, BUILD-008, BUILD-004, BUILD-012]
---
`CMakeLists.txt` defines five options:

- `DIANA_BUILD_TEST` (OFF): builds `test/c/` and registers it with ctest; outside scikit-build it
  also adds the `install` and `find_package` tests (BUILD-009).
- `DIANA_BUILD_PYTHON` (ON): builds the extension `_diana`; requires
  `find_package(Python COMPONENTS Interpreter Development.Module REQUIRED)`. Forced ON (cache
  `FORCE`) when `SKBUILD` is defined (BUILD-003).
- `DIANA_BUILD_SHARED_LIB` (OFF): `add_library(diana SHARED)` instead of `STATIC` (BUILD-005).
- `DIANA_WERROR` (OFF): adds `-Werror` through `diana_set_strict_flag` (BUILD-007).
- `DIANA_SANITIZER` (OFF): ASan and UBSan (BUILD-008).

Other settings: C11 required without extensions, `CMAKE_EXPORT_COMPILE_COMMANDS ON`, and on
`diana` `POSITION_INDEPENDENT_CODE ON` (a static `libdiana` links into the extension module) and
`C_VISIBILITY_PRESET default`; a shared library exports only the functions of
`cmake/symbol.txt` (BUILD-012).

Who sets what: `pyproject.toml` passes `-DDIANA_BUILD_PYTHON=ON -DDIANA_BUILD_TEST=OFF` to
scikit-build-core; `script/dev.sh config` passes `-DDIANA_BUILD_TEST=ON -DDIANA_WERROR=ON`,
`DIANA_SANITIZER` from the environment (default ON), `CMAKE_BUILD_TYPE` (default Debug) and
`-DPython_EXECUTABLE=$PWD/.venv/bin/python`; the C-only CI jobs pass `-DDIANA_BUILD_PYTHON=OFF`.
