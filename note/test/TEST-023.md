---
id: TEST-023
title: RK4 overflow and non-finite input cases
kind: fact
path:
  - test/c/test_rk4.c
  - test/python/test_rk4.py
related: [TEST-021, TEST-024]
---
Every RK4 overflow case has finite inputs and overflows in exactly one operation; the checked
function returns `DIANA_ERR_OVERFLOW` with all 100 output slots still at the sentinel 42. The
non-finite input cases below return `DIANA_ERR_ARG`, also with the output untouched.

- Stage: the product with `c = h` (`0 + 2 * DBL_MAX`, stage 4); the product with `c = h/2`
  (`h = DBL_MAX`, `k = 4`, stage 2; with `k = 2` the result is exactly `DBL_MAX` and succeeds);
  the sum (`DBL_MAX + 1 * DBL_MAX`, stage 3 with `h = 2`).
- Step, one operation each: `k2 + k3` (`DBL_MAX + DBL_MAX`); the doubling `2 (k2 + k3)`
  (`k2 = DBL_MAX`); the slope sum (`k1 = DBL_MAX`, `k2 = DBL_MAX/2`); `h * s` (`k1 = DBL_MAX`,
  `h = 2`); the final sum (`y = DBL_MAX`, `k1 = 2^1020`, `h = 6`: `h s = 1.5 * 2^1022` is finite,
  `DBL_MAX + 2^1020` is not). Finite: `k1 + k4` cancelling `DBL_MAX - DBL_MAX`, and
  `DBL_MAX + 1` rounding back to `DBL_MAX`.
- Non-finite input, stage: NaN and `+inf` in each `y[i]`, NaN and `-inf` in each `k[i]`, NaN and
  `±inf` as `h`; `inf - inf` (stage 2) and `1 + 0 * inf` (stage 4) are NaN.
- Non-finite input, step: NaN and `-inf` in each `y[i]`, NaN and `+inf` in each component of each
  slope, NaN and `±inf` as `h`; `inf - inf` in `k1 + k4` and in `k2 + k3`, and `0 * inf`, give
  NaN.
- Classification, stage (`test_stage_overflow_classify`): `y = k = (DBL_MAX, 1, 1)` with `h = 2`
  at stage 4 overflows in the first component, `DIANA_ERR_OVERFLOW`; NaN in `y[2]` or `+inf` in
  `k[2]` makes it `DIANA_ERR_ARG`.
- Classification, step (`test_step_overflow_classify`): `y` and `k1 .. k4` all `(DBL_MAX, 1, 1)`
  with `h = 1` overflow in `k2 + k3`, `DIANA_ERR_OVERFLOW`; NaN or `-inf` in component 2 of any one
  of the five arrays in turn makes it `DIANA_ERR_ARG`. The kernels check every input, not only
  those up to the failing operation.
- Python: `test_stage_overflow` and `test_step_overflow` raise `diana.FloatOverflowError` ("result
  overflows"); `test_stage_nonfinite` and `test_step_nonfinite` raise a plain `ValueError` ("input
  is not finite", never a `FloatOverflowError`), also for a NaN or `inf` after an overflowing
  component. `test_step_overflow_then_nonfinite` puts a NaN at component 2 of each argument of an
  overflowing step (`h = 6`, `y = k1 = (DBL_MAX, 1, 1)`, other slopes 0): the error class changes.
