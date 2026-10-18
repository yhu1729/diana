---
id: BUILD-008
title: DIANA_SANITIZER placement and exported link options
kind: fact
path:
  - CMakeLists.txt
related: [BUILD-002, BUILD-009]
---
With `DIANA_SANITIZER=ON` and a `GNU`, `Clang` or `AppleClang` compiler, `CMakeLists.txt` calls
`add_compile_options(-fsanitize=address,undefined -fno-omit-frame-pointer)` before
`add_library(diana)` and adds `target_link_options(diana PUBLIC -fsanitize=address,undefined)`.
Another compiler, which configures only with `DIANA_ALLOW_UNKNOWN_COMPILER` (BUILD-013), gets a
CMake `WARNING` and no sanitizer.

- `add_compile_options` is directory-scoped and reaches only targets created after the call, so
  it must precede `add_library(diana)`; it then instruments `diana`, the C tests under `test/c/`
  and `_diana`.
- The link options are `PUBLIC`, so they are part of `diana::diana`'s usage requirements: a target
  that links the library, in the build tree or through the installed `dianaTargets.cmake`, links
  the sanitizer runtimes too. The ctest `find_package` consumer of a sanitized build relies on it.
- `script/dev.sh config` turns it ON by default (`DIANA_SANITIZER` in the environment), CI's
  Debug jobs turn it ON and the Release jobs OFF; `script/check_wheel.py` forces it OFF, and the
  `uv sync` build never sets it.
