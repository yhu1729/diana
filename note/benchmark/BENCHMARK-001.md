---
id: BENCHMARK-001
title: What script/benchmark.sh builds and test/benchmark/unchecked.c times
kind: fact
path:
  - script/benchmark.sh
  - test/benchmark/unchecked.c
related: [BENCHMARK-002, BENCHMARK-004, BENCHMARK-005, KERNEL-002]
---
`script/benchmark.sh [cc...]` (default `cc`) times the checked against the unchecked Euler and RK4
kernels, through the static library, once per compiler given.

- Build: for each compiler a CMake build in a temporary directory with `CC=<cc>`,
  `CMAKE_BUILD_TYPE=Release`, `DIANA_BUILD_PYTHON=OFF`, `DIANA_BUILD_SHARED_LIB=OFF`: the library
  gets CMake's Release flags (`-O3 -DNDEBUG` with gcc and clang) plus the project's
  `-ffp-contract=off -fno-fast-math` (and `-fexcess-precision=standard` with GCC). The driver is
  compiled separately at `-O2 -ffp-contract=off` with `-Werror` warnings and linked against
  `libdiana.a`. On macOS an unset `MACOSX_DEPLOYMENT_TARGET` is set to `sw_vers -productVersion`.
  The script prints `uname -sm` first and removes its temporary directory on exit.
- Cases: `euler step`, `rk4 stage` (stage 2) and `rk4 step`, each called alone with `h = 0.01`
  on fixed inputs; `euler + rhs` (right-hand side then step) and `rk4 + rhs` (four right-hand
  sides, stages 2 to 4, step), which advance the state with `h = 1e-9` and swap `y` and `out`.
  The right-hand side is the driver's own `y' = -y/2`, chosen as the cheapest one.
- Measure: for `d` = 64, 1024 and 16384, each case runs `2e8 / d` calls (about `2e8` components),
  timed with `CLOCK_MONOTONIC` after an untimed refill of the inputs (values in `[-0.5, 0.5)`).
  It reports the best of 7 runs as nanoseconds per component of one call (one loop step for the
  `+ rhs` cases), checked and unchecked, and their ratio. Seven vectors of `d` doubles, at most
  896 KiB, are in use.
- Kernels are called through function pointers into the static library, without LTO, so nothing
  is inlined across the library boundary. A status other than `DIANA_OK` aborts the run.
- The driver prints `compiler: __VERSION__` before each table (`Apple LLVM 21.0.0 (...)` for
  Apple clang, only `15.3.0` for GCC).
