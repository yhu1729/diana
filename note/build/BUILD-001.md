---
id: BUILD-001
title: Strict warning set of diana_set_strict_flag
kind: fact
path:
  - cmake/warning.cmake
  - test/c/CMakeLists.txt
related: [BUILD-007, BUILD-013, FP-004]
---
`diana_set_strict_flag(<target>)` in `cmake/warning.cmake` adds, as `PRIVATE` compile options:

`-Wall -Wextra -Wconversion -Wshadow -Wvla -Wpedantic -Wstrict-prototypes -Wmissing-prototypes
-Wcast-qual -Wpointer-arith -Wundef -Wdouble-promotion -ffp-contract=off -fno-fast-math
-fno-math-errno`,
plus `-fexcess-precision=standard` when the compiler ID is `GNU`, and `-Werror` when
`DIANA_WERROR` is ON (BUILD-007).

- It applies to compiler IDs exactly `GNU`, `Clang` and `AppleClang` (an anchored match); another
  compiler gets no option, and configuration refuses it unless `DIANA_ALLOW_UNKNOWN_COMPILER` is
  ON (BUILD-013).
- Targets: the library `diana` and the extension `_diana` (`CMakeLists.txt`), and every C test
  `test_<name>` (`diana_add_test` in `test/c/CMakeLists.txt`). The installed-consumer project in
  `test/install/` does not use it.
- `PRIVATE`: nothing propagates to a target that links `diana::diana`.
- The C standard is set separately: `CMAKE_C_STANDARD 11`, required, without extensions.
- `script/compare_compiler.sh` repeats the same warning list with `-Werror`, and
  `test/doc/test_example.py` a subset (with `-pedantic`), for builds outside CMake.
