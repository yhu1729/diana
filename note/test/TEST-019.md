---
id: TEST-019
title: Euler callback wrapper cases keep every iterate exact
kind: fact
path:
  - test/c/test_euler.c
  - test/python/test_euler.py
  - src/euler.c
related: [TEST-016, TEST-025]
---
The `diana_euler` tests use right-hand sides whose iterates are exactly representable, so the
expected states are exact; the wrapper evaluates `fn` at `t0 + k h` and copies each accepted step
into `y`.

- `y' = -y` from `(1, 3)` with `h = 1/2`: each step halves the state, `(0.125, 0.375)` after three
  steps, `done == 3`.
- Rotation `y' = (y2, -y1)` from `(1, 0)` with `h = 1`: `(1, -1)`, `(0, -2)`, `(-2, -2)`.
- `y' = t` from `t0 = 1`, `y = 0`, `h = 1/4`, four steps: `fn` is called at `1, 1.25, 1.5, 1.75`
  with the caller's `ctx`, and `y = (1 + 1.25 + 1.5 + 1.75) / 4 = 1.375`.
- `nstep = 0` calls nothing and leaves `y`; NULL `fn`, `y` or `work`, `d = 0`, `lwork = 3`
  for `d = 2`, and `d = SIZE_MAX/2 + 1` (whose `2d` wraps) are `DIANA_ERR_ARG` with `done = 0`
  and no call (`test_wrapper_work_size`).
- `test_wrapper_callback`: `y' = t` from 0 with `h = 1` and a callback that returns 1 on its third
  call gives `DIANA_ERR_CALLBACK`, `done = 2`, `y = 1` (after `0` and `1`), three calls.
- Failure: a derivative that turns infinite on the third call stops with `DIANA_ERR_ARG` after two
  steps, `y` at the second state and three calls; `y' = -y` with `h = -2` from `DBL_MAX/2`
  overflows (`y + 2y`) on the first step, `DIANA_ERR_OVERFLOW`, and leaves `y` unchanged,
  `done = 0`. The wrapper passes the step's status through.
- Python `diana.euler` gives the same exact paths and times, copies `y0` (a NumPy input is left
  unchanged), calls nothing for `nstep = 0`, checks the callback's length, and raises a plain
  `ValueError` ("not finite", not a `FloatOverflowError`) after exactly three calls when the third
  returns `inf`. `test_euler_overflow`: `y' = y` from `2^1021` with `h = 1` doubles the state, and
  the third step passes `DBL_MAX`, raising `FloatOverflowError` ("overflows").
