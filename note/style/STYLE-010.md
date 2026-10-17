---
id: STYLE-010
title: C11 with a strict warning set; -Werror through DIANA_WERROR
kind: rule
path:
  - CMakeLists.txt
  - cmake/warning.cmake
related: [FP-001, FP-004, KERNEL-001, CMAKE-002, API-002]
---
The library is C11: `CMAKE_C_STANDARD 11` with `CMAKE_C_STANDARD_REQUIRED ON` and
`CMAKE_C_EXTENSIONS OFF`, so `-std=c11`, not a GNU dialect. Code must stay clean under the
warning set `diana_set_strict_flag` (`cmake/warning.cmake`) gives the `diana` library, the `_diana`
extension and every ctest executable on GCC and Clang: `-Wall -Wextra -Wconversion -Wshadow -Wvla
-Wpedantic -Wstrict-prototypes -Wmissing-prototypes -Wcast-qual -Wpointer-arith -Wundef
-Wdouble-promotion`, plus the floating-point flags of FP-004.

`-Werror` is added only with the CMake option `DIANA_WERROR`, OFF by default so that end-user
builds survive warnings a newer compiler adds. Every project build turns it on: the CI build,
`test_install` and `coverage_c` jobs, the `.uv` jobs through `SKBUILD_CMAKE_DEFINE`,
`script/check_wheel.py`, and `script/dev.sh config` and its `uv sync`.

Library code also keeps these rules:

- every public name has the prefix `diana_` (macros and enum constants `DIANA_`);
- buffers are caller-owned: no `malloc` in `src/`;
- public functions return `diana_status` (API-002), except `diana_version` and
  `diana_status_str`, which return `const char *`;
- no libm call in a verified kernel (FP-001), and the kernel shape of KERNEL-001.

Format with clang-format (STYLE-005).
