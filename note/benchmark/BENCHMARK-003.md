---
id: BENCHMARK-003
title: Recorded benchmark output with GCC 15.3 on an Apple M4 Mac
kind: fact
path:
  - script/benchmark.sh
  - test/benchmark/unchecked.c
related: [BENCHMARK-001, BENCHMARK-002, BENCHMARK-004]
---
The second half of the recorded run of `script/benchmark.sh cc gcc-15` on 2026-10-18 (machine in
BENCHMARK-002): Homebrew GCC 15.3.0, whose `__VERSION__` is only `15.3.0`.

```
compiler: 15.3.0
     d  kernel        checked  unchecked  ratio  (ns per component, best of 7)
    64  euler step      0.442      0.152    2.9
    64  rk4 stage       0.447      0.156    2.9
    64  rk4 step        0.925      0.420    2.2
    64  euler + rhs     0.681      0.413    1.6
    64  rk4 + rhs       3.130      1.717    1.8
  1024  euler step      0.515      0.136    3.8
  1024  rk4 stage       0.506      0.134    3.8
  1024  rk4 step        0.907      0.414    2.2
  1024  euler + rhs     0.778      0.415    1.9
  1024  rk4 + rhs       3.506      1.897    1.8
 16384  euler step      0.526      0.182    2.9
 16384  rk4 stage       0.525      0.161    3.3
 16384  rk4 step        0.977      0.417    2.3
 16384  euler + rhs     0.833      0.454    1.8
 16384  rk4 + rhs       3.789      2.019    1.9
```

Against Apple clang, GCC's unchecked kernels gain less (ratios 2.2 to 3.8 against 2.9 to 4.8 for
the kernels alone), and its `+ rhs` rows are slower in both columns. Its unchecked RK4 step
measured 0.26 to 0.37 ns in the 2026-10-17 run and 0.41 to 0.42 ns here although that source is
unchanged; code layout is the likely cause, not confirmed.
