# Explicit Euler step test values

## C

Expected values in `test/c/test_euler.c`:

- Exact steps use values with few significant bits, so the product and the sum are exact; the
  100-component case checks `y_out[i] = i/2 - 48.5`.
- `y = -1`, `h = 1 + 2^-52`, `f = 1 - 2^-52` pins the separately rounded product:
  `h * f = 1 - 2^-104` rounds to 1 and the result is `+0`, where a fused multiply-add would give
  `-2^-104`.
- `h = 0` keeps each `y[i]`, including its sign of zero (`+0 + -0 = +0`, `-0 + -0 = -0`).
- `0.5 * DBL_TRUE_MIN` is a tie that rounds to `+0`: underflow is not an error. `DBL_MAX + 1`
  rounds back to `DBL_MAX`, a finite result.
- Overflow cases have finite inputs and overflow in exactly one operation, the product or the sum.
- Two failing cases, one in the last component and one in the first, check that `y_out` keeps its
  sentinel values: the first pass rejects before the second pass writes.
- The wrapper cases keep every iterate exact: `y' = -y` with `h = 1/2` halves the state each step,
  the rotation `y' = (y2, -y1)` with `h = 1` stays on integers (`(1, 0)` to `(-2, -2)` in three
  steps), and `y' = t` from `t0 = 1` with `h = 1/4` records the times `1, 1.25, 1.5, 1.75` and ends
  at `(1 + 1.25 + 1.5 + 1.75) / 4 = 1.375`. A derivative that turns infinite on the third call
  stops after two steps with `y` at the second state, and `y' = -y` with `h = -2` from `DBL_MAX/2`
  overflows on the first step and leaves `y` unchanged.

## Python

Expected values in `test/python/test_euler.py`, beyond the cases it shares with the C test:

- The Hypothesis test draws `y` and `f` of equal length (1 to 20) and requires bitwise agreement
  with `y[i] + h*f[i]` in Python floats, which round the product and the sum separately, and
  `ValueError` exactly when a component is not finite.
- The rounding test checks EULER-B2 on 500 random components in the normal range and 500 with
  subnormal inputs, against exact `fractions.Fraction` arithmetic.
- The convergence test integrates the rotation `y' = (y2, -y1)` from `(0, 1)` to `t = 1`, where
  the solution is `(sin t, cos t)`. In the max norm `F` is 1-Lipschitz and `|y''| <= 1`, so
  EULER-A2 bounds the error by `(h/2)(e - 1)`; the measured error is about 0.49 of that. Halving
  `h` divides the error by 2 up to an O(h) correction, measured at most 0.016 for `h <= 1/16`
  (ratios 1.985 to 1.999); rounding, about `n u`, is far below the smallest error
  of about 1.6e-3. The test allows 0.05.
- The extension's own `out` checks are tested directly on `diana._diana.euler_step`: a read-only
  `out` (`BufferError`), a length mismatch, and `out` equal to or overlapping `y` or `f`.
