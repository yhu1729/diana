# Benchmark

`script/benchmark.sh [cc...]` (default `cc`) builds the static library in Release (`-O3`, with the
project's `-ffp-contract=off`) with each compiler and runs `test/benchmark/unchecked.c` against
it. The driver times the checked and unchecked Euler step, RK4 stage (stage 2) and RK4 step, each
alone, and a whole Euler step and a whole RK4 step (four slopes, three stages, one step) with the
right-hand side `y′ = −y/2`. It reports nanoseconds per component for `d` = 64, 1024 and 16384,
the best of 7 runs of about 2·10⁸ components each, with data that stays in cache and finite (the
loops use `h = 10⁻⁹`, so the state barely moves). The kernels are called through the library, as
a caller would, so no call is inlined across the library boundary.

The figures in the [Euler](../api/euler.md) and [RK4](../api/rk4.md) pages and in `CHANGELOG.md`
are this output, from `script/benchmark.sh cc gcc-15` on 2026-10-17: an Apple M4 Mac (24 GB,
macOS 27.0.1, `Darwin arm64`) with Apple clang 21.0.0 (clang-2100.3.34.2) and Homebrew GCC 15.3.0.
They depend on the machine and the compiler, so treat them as orders of magnitude elsewhere.

```text
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

The unchecked kernels gain because they make one pass with no branch, which the compilers
vectorize. The checked ones make two passes and stop at the first non-finite component. Per
component, the unchecked Euler step and RK4 stage save 0.3 to 0.4 ns, and the RK4 step 0.6 to
0.9 ns. A whole RK4 step therefore saves 1.3 to 2.0 ns, small next to a right-hand side that
costs a few nanoseconds per component.
