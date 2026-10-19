---
id: BENCHMARK-002
title: Benchmark results stay local; the docs say how to measure, not what was measured
kind: rule
path:
  - doc/api/euler.md
  - doc/api/rk4.md
  - doc/development/benchmark.md
  - note/api/API-019.md
  - script/benchmark.sh
related: [BENCHMARK-001, BENCHMARK-007]
---
No benchmark output is committed: `script/benchmark.sh` writes under `build/`, there is no
result directory in the tree, and the documentation and the notes quote no timing. A performance
claim in `doc/` or `note/` is qualitative (one pass against two, vectorized against not, several
times faster) and points the reader to `script/benchmark.sh` to measure it on their own machine
and compiler; `doc/development/benchmark.md` says how to run it and read the table.

- Why: a timing is a fact about one machine, compiler and commit, which a reader cannot check
  and which goes stale with any of the three; the suite, run locally, is the figure of record.
- A released `CHANGELOG.md` section keeps whatever figures it quoted at the time (the `1.0.0`
  section quotes the former driver's run); do not add new ones.
- The explanation of the unchecked kernels' gain, that they make one branch-free pass the
  compilers vectorize while the checked kernels make two passes with an early exit, matches the
  source but was not confirmed by inspecting the generated code.
- A change that could move the numbers (a kernel, the compile flags, a driver, the harness) is
  checked by running `script/benchmark.sh` before and after, locally; nothing in CI does
  (BENCHMARK-003).
