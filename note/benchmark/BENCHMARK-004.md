---
id: BENCHMARK-004
title: Quoted performance figures come from the recorded benchmark run
kind: rule
path:
  - doc/api/euler.md
  - doc/api/rk4.md
  - CHANGELOG.md
  - script/benchmark.sh
related: [BENCHMARK-001, BENCHMARK-002, BENCHMARK-003]
---
Every performance figure in the documentation, the notes and `CHANGELOG.md` must be derived from
the recorded output (BENCHMARK-002, BENCHMARK-003). A change that could move the numbers (a
kernel, the compile flags, the driver) re-runs `script/benchmark.sh` and updates the recorded
output and every quoted figure in the same change. Nothing checks this automatically.

Figures currently quoted, with their derivation from the table (both compilers, all `d`):

- Euler step: unchecked 2.9 to 4.8 times faster, 0.10 to 0.18 ns per component against 0.44 to
  0.53, saving 0.3 to 0.4 ns.
- RK4 stage: 2.9 to 4.8 times, 0.10 to 0.20 ns against 0.45 to 0.58, saving 0.3 to 0.4 ns.
- RK4 step: 2.2 to 4.6 times, 0.25 to 0.42 ns against 0.91 to 1.28, saving 0.5 to 0.9 ns.
- Whole RK4 step (`rk4 + rhs`): saving 1.4 to 2.0 ns per component.

The explanation given with them, that the unchecked kernels make one branch-free pass the
compilers vectorize while the checked kernels make two passes with an early exit, matches the
source but was not confirmed by inspecting the generated code. The claim that the saving is small
next to a right-hand side costing a few nanoseconds per component is an assumption about real
right-hand sides: the benchmark's own `y' = -y/2` costs only about 0.06 to 0.3 ns per component
(`euler + rhs` minus `euler step`), and in the `rk4 + rhs` rows the unchecked kernels save 45 to
72% of the checked time.
