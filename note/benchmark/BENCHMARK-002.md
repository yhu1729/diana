---
id: BENCHMARK-002
title: Recorded benchmark output with Apple clang 21 on an Apple M4 Mac
kind: fact
path:
  - script/benchmark.sh
  - test/benchmark/unchecked.c
related: [BENCHMARK-001, BENCHMARK-003, BENCHMARK-004]
---
The performance figures quoted in the API pages and `CHANGELOG.md` come from one run of
`script/benchmark.sh cc gcc-15` on 2026-10-18: an Apple M4 Mac (24 GB, macOS 27.0.1,
`Darwin arm64`) with Apple clang 21.0.0 (clang-2100.3.34.2), whose table is below, and Homebrew
GCC 15.3.0 (BENCHMARK-003). The machine description was recorded with the run; the script prints
only `Darwin arm64`, omitted here. The figures depend on the machine and the compiler; elsewhere
treat them as orders of magnitude.

```
compiler: Apple LLVM 21.0.0 (clang-2100.3.34.2)
     d  kernel        checked  unchecked  ratio  (ns per component, best of 7)
    64  euler step      0.465      0.106    4.4
    64  rk4 stage       0.465      0.106    4.4
    64  rk4 step        1.129      0.255    4.4
    64  euler + rhs     0.523      0.217    2.4
    64  rk4 + rhs       2.782      0.992    2.8
  1024  euler step      0.473      0.098    4.8
  1024  rk4 stage       0.475      0.099    4.8
  1024  rk4 step        1.143      0.250    4.6
  1024  euler + rhs     0.543      0.165    3.3
  1024  rk4 + rhs       2.843      0.804    3.5
 16384  euler step      0.534      0.154    3.5
 16384  rk4 stage       0.575      0.197    2.9
 16384  rk4 step        1.283      0.368    3.5
 16384  euler + rhs     0.704      0.329    2.1
 16384  rk4 + rhs       3.592      1.558    2.3
```
