---
id: TEST-022
title: RK4 rounding pins for FMA, the h/2 coefficient and the slope-sum order
kind: fact
path:
  - test/c/test_rk4.c
  - test/python/test_rk4.py
related: [TEST-021, TEST-016, FP-004]
---
Three RK4 cases fix how each operation is rounded; a kernel that fused, reassociated or computed
the coefficient differently would fail them. The C test, the Python test and the compiler corpus
carry all three.

- No contraction in the stage: `y = -1`, `k = 1 - 2^-52`, `c = 1 + 2^-52`. The product
  `c k = 1 - 2^-104` rounds to 1 and the result is `+0`, where an FMA would give `-2^-104`. It is
  run at stage 4 with `h = c` and at stage 2 with `h = 2c` (`h/2 = c` exactly).
- Coefficient rounded first: `h = 3 * 2^-1074` at stages 2 and 3. `h/2` is a tie that rounds to
  even, `2 * 2^-1074`, so with `y = 0`, `k = 1024` the result is `2048 * 2^-1074 = 2^-1063`,
  whereas `(h * k) / 2` would be the exact `3 * 2^-1065`.
- Slope-sum grouping: `y = 0`, `k1 = 1`, `k2 = k3 = 2^-54`, `k4 = 2^-53`, `h = 6`. `k1 + k4` is a
  tie that rounds to 1, `2 (k2 + k3) = 2^-52`, so `s = 1 + 2^-52`; `6 s` rounds to `6 + 2^-49`
  and dividing by 6 gives `1 + 2^-52`, the expected value. Summing left to right would give 1,
  and the correctly rounded sum `1 + 2^-51`.
