---
id: BENCHMARK-003
title: Recorded benchmark output with GCC 15.3 on an Apple M4 Mac
kind: fact
path:
  - script/benchmark.sh
  - test/benchmark/unchecked.c
related: [BENCHMARK-001, BENCHMARK-002, BENCHMARK-004]
---
The second half of the recorded run of `script/benchmark.sh cc gcc-15` on 2026-10-17 (machine in
BENCHMARK-002): Homebrew GCC 15.3.0, whose `__VERSION__` is only `15.3.0`.

```
compiler: 15.3.0
     d  kernel        checked  unchecked  ratio  (ns per component, best of 7)
    64  euler step      0.440      0.151    2.9
    64  rk4 stage       0.444      0.155    2.9
    64  rk4 step        0.911      0.279    3.3
    64  euler + rhs     0.673      0.407    1.7
    64  rk4 + rhs       3.088      1.765    1.7
  1024  euler step      0.505      0.132    3.8
  1024  rk4 stage       0.506      0.133    3.8
  1024  rk4 step        0.861      0.258    3.3
  1024  euler + rhs     0.758      0.411    1.8
  1024  rk4 + rhs       3.429      1.716    2.0
 16384  euler step      0.522      0.190    2.8
 16384  rk4 stage       0.555      0.171    3.2
 16384  rk4 step        0.966      0.372    2.6
 16384  euler + rhs     0.821      0.445    1.8
 16384  rk4 + rhs       3.719      1.997    1.9
```

Against Apple clang, GCC's unchecked kernels gain less (ratios 2.6 to 3.8 against 3.1 to 4.8 for
the kernels alone), and its `+ rhs` rows are slower in both columns.
