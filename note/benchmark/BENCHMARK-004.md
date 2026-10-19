---
id: BENCHMARK-004
title: How the driver times a case and what its table shows
kind: fact
path:
  - benchmark/benchmark.h
  - benchmark/harness.c
  - benchmark/main.c
related: [BENCHMARK-001, BENCHMARK-005, BENCHMARK-006]
---
`benchmark/main.c` runs every case of every suite in order, or the cases whose name starts with
an argument (`benchmark euler_step` runs `euler_step` and `euler_step_unchecked`); `--list`
prints the names; no match exits with status 2.

- A case (`struct diana_benchmark_case`, `benchmark/benchmark.h`) is a name, a unit name, a size
  list (`NULL` for the scalar kernels, whose `n` prints as `-`), `setup(n)`, `run(data)` returning
  the units of work one call did (0 on a failed call, which aborts the run), and `teardown`. The
  size lists are vectors 64, 1024, 16384; quadrature samples 65, 1025, 16385; matrices 16, 64,
  256. Each method's cases are one `const struct diana_benchmark_suite` in `benchmark/<method>.c`,
  listed in `main.c`.
- Timing (`diana_benchmark_time`, `benchmark/harness.c`): `CLOCK_MONOTONIC`; the calls per trial
  double from 1 until a trial lasts at least 50 ms, then that trial and six more are the best of
  7; the row reports the best trial's nanoseconds per call and, divided by the units per call,
  per unit. Inputs are filled once in `setup` by splitmix64 from a fixed seed, values in
  `[-0.5, 0.5)` (`diana_benchmark_fill`), so a run is deterministic apart from time.
- Units: `component` (one vector entry, or one entry of one step in the whole-step and wrapper
  cases), `sample`, `step` (one bisection or Newton step), `flop` (the conventional count:
  `n³/3` Cholesky, `n²` a triangular solve, `2n³/3` LU, `2n²` LU solve).
- Successive calls are independent, so at small `n` the out-of-order core overlaps them: the
  65-sample `trapezoidal` row comes out well below what a chain of 63 dependent additions takes,
  although the kernel is that chain. A row is the throughput of back-to-back calls, not the
  latency of one; compare rows at equal `n`, and read the largest `n` for the kernel alone.
- The driver prints `compiler: __VERSION__` (`15.3.0` for GCC) and a method line, then the
  table `kernel  n  ns/call  ns/unit  unit`, flushing after each row.
