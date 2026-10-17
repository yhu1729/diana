---
id: TEST-020
title: Euler Python property, rounding, convergence and out-buffer tests
kind: fact
path:
  - test/python/test_euler.py
related: [TEST-016, TEST-026, API-004]
---
`test/python/test_euler.py` checks `diana.euler_step` against Python floats, the EULER-B2 bound in
exact arithmetic, first-order convergence of `diana.euler`, and the extension's own `out` checks.

- Property (Hypothesis, 500 derandomized examples, no example database): `y` and `f` of equal
  length 1 to 20, any floats, any `h`. The result must equal `y[i] + h*f[i]` in Python floats
  (product and sum rounded separately) bit for bit, and `ValueError` must be raised exactly when a
  component is not finite.
- Rounding (seed 1729): 500 components with magnitudes `2^k`, `k` in `[-40, 40]`, and 500 with
  `k` in `[-1074, -1000]` (subnormal inputs), `h` uniform in `(-1, 1)`; each component must
  satisfy `|r - (y + h f)| <= u |y + h f| + (1 + u)(u |h f| + eta)` in `fractions.Fraction`.
- Convergence: the rotation `y' = (y2, -y1)` from `(0, 1)` to `t = 1`, exact `(sin t, cos t)`,
  with `n = 16, ..., 256` steps. In the max norm `F` is 1-Lipschitz and `|y''| <= 1`, so
  EULER-A2 bounds the error by `(h/2)(e - 1)`; the test requires `0 < err` below it (measured
  about 0.49 of it) and each halving of `h` to divide the error by 2 within `0.05` (measured
  1.985 to 1.999). Rounding, about `n u`, is far below the smallest error, about `1.6e-3`.
- `diana._diana.euler_step(y, f, h, out)` directly: a non-buffer `y` is `TypeError`, a read-only
  `out` `BufferError`, an empty `out` or one of another length `ValueError`, and `out` equal to
  `y` or `f` or overlapping `y` `ValueError` ("overlap"); a valid call returns `None` and fills
  `out`.
