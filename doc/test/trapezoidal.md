# Composite trapezoidal rule test values

Expected values in `test/c/test_trapezoidal.c` and `test/python/test_trapezoidal.py`:

- The rule is exact for affine `f`. The affine cases use samples and `h` with few significant bits
  (integers or quarter-integers, `h` in `{1/2, 3/4, 2^-7}`), so every partial sum and the final
  product are representable and the binary64 result equals the integral: 20 for `2x + 1` on
  `[0, 4]`, 16.5 for `7 - x` on `[0, 3]`, and `1000 * 500 / 128 = 3906.25` for `3i - 1000`,
  `i = 0..1000`, whose samples change sign.
- `y = {2^53, 1, 1, 2^53}` pins the summation order: after the halved endpoints, `2^53 + 1` is a tie
  that rounds to even, `2^53`, at each interior step, so the result is `2^53` rather than the exact
  `2^53 + 2` that summing the interior first would give.
- Overflow cases have finite samples and `h` and overflow in exactly one operation: the endpoint
  sum (`{DBL_MAX, DBL_MAX}`, whose exact rule `DBL_MAX` is representable), an interior addition, or
  the product with `h`. `h = 0` does not mask an overflow in the sum, since `0 * inf` is NaN.
- `0.5 * DBL_TRUE_MIN` is a tie between 0 and the smallest subnormal and rounds to `+0`: underflow
  is a finite result, not an error.
- The Python Hypothesis test requires bitwise agreement (value and sign of zero) with the same
  sequential evaluation in Python floats, which are binary64 with separate rounded operations, and
  `ValueError` exactly when that evaluation is not finite.
- The rounding test checks the TRAPEZOIDAL-B2 bound against the rule evaluated exactly in
  `fractions.Fraction`, on scaled random samples in the normal range, on `{DBL_TRUE_MIN, 0}` with
  `h = 1` (the halving underflows: the result is 0 and the error is `eta = 2^-1075`), and on
  samples near `2^-1000` with `h = 0.1 * 2^-60` (the product underflows). In both underflow cases
  the error exceeds the `gamma_n |h| A` term alone, so the `eta` terms are needed.
- The convergence test integrates `exp` on `[0, 1]` against `e - 1` from mpmath at 40 digits, for
  `m = 16, ..., 256` panels. TRAPEZOIDAL-A2 with `M2 = e` bounds the error by `e h^2 / 12`, and
  convexity makes it positive. By Euler-Maclaurin the error is
  `(e - 1) h^2 / 12 - (e - 1) h^4 / 720 + O(h^6)`, so each halving of `h` divides it by
  `4 (1 - h^2 / 80) + O(h^4)`, within `2e-4` of 4 for `h <= 1/16`; the test allows `1e-3`. Rounding
  and the error of `math.exp` (about `1e-13` in all) are negligible against the smallest error,
  about `2e-6`.
