---
id: TEST-025
title: RK4 callback wrapper cases keep every stage and iterate exact
kind: fact
path:
  - test/c/test_rk4.c
  - test/python/test_rk4.py
  - src/rk4.c
related: [TEST-019, TEST-021]
---
The `diana_rk4` tests use right-hand sides whose stages and iterates are exactly representable.
The wrapper calls `fn` at `t0 + k h`, `t0 + (k + 1/2) h` twice and `t0 + (k + 1) h`, building the
stages with `diana_rk4_stage` and the step with `diana_rk4_step` in a work area of `5d` doubles.

- `y' = -y` with `h = 1`: the stages are `y, y/2, 3y/4, y/4` and each step multiplies by
  `1 - 1 + 1/2 - 1/6 + 1/24 = 3/8`: `(64, -8)` becomes `(3.375, -0.421875)` after three steps.
- Rotation `y' = (y2, -y1)` with `h = 6`: one step is `37 I - 30 A`, so `(1, 0)` goes to
  `(37, 30)`, and a second call from `t0 = 6` to `(469, 2220)`.
- `y' = t` from `t0 = 1`, `y = 0`, `h = 1/4`, two steps: eight calls at
  `1, 1.125, 1.125, 1.25, 1.25, 1.375, 1.375, 1.5` with the caller's `ctx`, and `y` ends at the
  exact `(1.5^2 - 1) / 2 = 0.625`, since RK4 is Simpson's rule for `y' = g(t)`.
- Failure: an infinite slope at call 1, 2, 3 or 4 of the first step (from `t0 = 0`, `h = 1`)
  fails the stage that uses `k1`, `k2` or `k3`, or the step for `k4`, with `DIANA_ERR_ARG`, `y`
  unchanged and `done = 0`; one at the second step's `k2` stops after one step at `y = 1/2`.
  `y' = -y` with `h = -2` from `DBL_MAX/2` reaches `Y2 = DBL_MAX` and overflows in
  `Y3 = y + DBL_MAX`: `DIANA_ERR_OVERFLOW`, `y` unchanged, `done = 0`.
- `nstep = 0` calls nothing; NULL `fn`, `y` or `work` and `d = 0` are `DIANA_ERR_ARG`.
- Python `diana.rk4` reproduces the exact paths, times and `0.625`, also when `f` returns the same
  NumPy array on every call (the driver copies each slope), and stops after `fail + 1` calls with
  a plain `ValueError` ("not finite", not a `FloatOverflowError`). `test_rk4_overflow`:
  `y' = y` from `DBL_MAX/2` with `h = 1` reaches the stage 4 point `y + k3 = (11/8) DBL_MAX` and
  raises `FloatOverflowError` ("RK4 stage result overflows").
