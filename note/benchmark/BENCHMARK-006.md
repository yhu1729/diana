---
id: BENCHMARK-006
title: Linear algebra, norm and axpy benchmark cases and their inputs
kind: fact
path:
  - benchmark/cholesky.c
  - benchmark/substitution.c
  - benchmark/lu.c
  - benchmark/lu_solve.c
  - benchmark/norm.c
  - benchmark/axpy.c
related: [BENCHMARK-004, BENCHMARK-005]
---
Matrices are column-major `n × n` as the kernels take them, `n` = 16, 64 and 256; the largest
is 512 KiB, so the `n = 256` rows run partly from the second-level cache, with a visibly higher
per-flop time, and a per-flop figure is comparable only at equal `n`.

- `cholesky`: `A[i, j] = 1/(1 + |i − j|) + n·[i = j]` (`diana_benchmark_spd` in
  `benchmark/harness.c`), symmetric and diagonally dominant, so positive definite and well
  conditioned at every `n`; factored into a separate `l`; units `n³/3`.
- `forward_substitution`, `transpose_substitution`: `L` the Cholesky factor of that `A`,
  computed in `setup` (a failure aborts the run), `b` random; `‖L⁻¹‖₂ = λ_min(A)^{-1/2} < 1`,
  so the solution stays bounded by `b`. Units `n²`.
- `lu`: `A` random in `[-0.5, 0.5)` with no structure, so partial pivoting interchanges rows;
  units `2n³/3`. `lu_solve`: the factors of that `A` from `diana_lu` in `setup`, `b` random;
  units `2n²`.
- `norm_1`, `norm_2`, `norm_inf`: `x` random, `n` = 64, 1024, 16384; units `n`.
- `axpy`, `axpy_unchecked`: `x` and `y` random, `n` = 64, 1024, 16384, `a = 1e-9` so that `y`,
  updated in place on every call, stays far from overflow over a run; units `n`. The two rows
  differ only in the kernel called (API-019).

Every input is finite and far from overflow, so each call returns `DIANA_OK`; a status other than
that aborts the run (BENCHMARK-004).
