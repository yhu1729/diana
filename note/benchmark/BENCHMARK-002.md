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
`script/benchmark.sh cc gcc-15` on 2026-10-17: an Apple M4 Mac (24 GB, macOS 27.0.1,
`Darwin arm64`) with Apple clang 21.0.0 (clang-2100.3.34.2), whose table is below, and Homebrew
GCC 15.3.0 (BENCHMARK-003). The machine description was recorded with the run; the script prints
only `Darwin arm64`, omitted here. The figures depend on the machine and the compiler; elsewhere
treat them as orders of magnitude.

```
compiler: Apple LLVM 21.0.0 (clang-2100.3.34.2)
     d  kernel        checked  unchecked  ratio  (ns per component, best of 7)
    64  euler step      0.450      0.105    4.3
    64  rk4 stage       0.451      0.105    4.3
    64  rk4 step        1.115      0.253    4.4
    64  euler + rhs     0.516      0.215    2.4
    64  rk4 + rhs       2.758      0.988    2.8
  1024  euler step      0.465      0.096    4.8
  1024  rk4 stage       0.467      0.096    4.8
  1024  rk4 step        1.122      0.248    4.5
  1024  euler + rhs     0.535      0.164    3.3
  1024  rk4 + rhs       2.798      0.800    3.5
 16384  euler step      0.519      0.168    3.1
 16384  rk4 stage       0.534      0.165    3.2
 16384  rk4 step        1.256      0.372    3.4
 16384  euler + rhs     0.700      0.325    2.2
 16384  rk4 + rhs       3.543      1.532    2.3
```
