---
id: BENCHMARK-001
title: What script/benchmark.sh builds, runs and writes
kind: fact
path:
  - script/benchmark.sh
  - benchmark/CMakeLists.txt
related: [BENCHMARK-003, BENCHMARK-004, BENCHMARK-007, COMPILER-003]
---
`script/benchmark.sh [cc...]` (default `cc`) builds the library and the suite in `benchmark/` in
Release with each compiler given, runs the suite and writes its output to a local file.

- Build: per compiler a CMake build in a temporary directory with `CC=<cc>`,
  `CMAKE_BUILD_TYPE=Release`, `DIANA_BUILD_PYTHON=OFF`, `DIANA_BUILD_SHARED_LIB=OFF`,
  `DIANA_BUILD_BENCHMARK=ON` and `DIANA_WERROR=ON`, target `benchmark`. The library and the
  drivers get CMake's Release flags (`-O3 -DNDEBUG` with gcc and clang) and the strict warning
  and floating-point flags of `diana_set_strict_flag` (BUILD-001); `benchmark/CMakeLists.txt`
  defines `_POSIX_C_SOURCE=200809L` for `clock_gettime`. The static library is linked without
  LTO, so no kernel is inlined into a driver. On macOS an unset `MACOSX_DEPLOYMENT_TARGET` is set
  from `sw_vers` (COMPILER-003). The temporary directory is removed on exit.
- Run: `<build>/benchmark/benchmark` without argument, every case (BENCHMARK-004). With
  `DIANA_BENCHMARK_CASE` set to case-name prefixes, the script runs only those and prints the
  output without writing a file.
- Write: `<DIANA_BENCHMARK_DIR>/<date>-<commit>-<machine>-<compiler>.txt`, the directory
  `build/benchmark/result` by default, under the ignored `build/` (BENCHMARK-007, BENCHMARK-002);
  `<commit>` is the short hash of `HEAD`, with `-dirty` appended when the tree has uncommitted
  changes (`git diff --quiet HEAD` fails), `unknown` outside a repository; never overwriting:
  an existing name gets the suffix `-2`, `-3`, ... The machine name is `DIANA_BENCHMARK_MACHINE`,
  else the CPU brand string (`sysctl -n machdep.cpu.brand_string` on macOS, `model name` of
  `/proc/cpuinfo` on Linux) without `(R)`, `(TM)`, ` CPU` and the clock, lowercased, each run of
  other characters replaced by `-` (`apple-m4`). The compiler name is `apple-clang-<major>`,
  `clang-<major>` or `gcc-<major>` from the first line of `<cc> --version`, else the command's
  base name. The file is also printed, followed by `written to <path>`.
- `-h` or `--help` prints the usage; any other option exits with status 2.
