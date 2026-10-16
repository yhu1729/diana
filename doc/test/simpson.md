# Composite Simpson rule test values

## C

Expected values in `test/c/test_simpson.c`:

- The rule is exact for cubic `f`. The cubic cases use samples and `h` with few significant bits,
  so every partial sum and the product with `h` are representable and only the division by 3 can
  round: 64 for `x^3` on `[0, 4]`; `28/3`, rounded once, for `x^3 - 2x^2 + x + 1` on `[-1, 3]` with
  `h = 1/2` (the weighted sum is exactly 56); and 26000007000 for `(i - 400)^3 + 7`,
  `i = 0..1000`, whose samples change sign (3250000875 with `h = 2^-3`).
- Three cases pin the operation order. `{2^53, 1/2, 1/4, 1/2, -2^53}` gives 4.5 because the
  endpoint pair cancels before the weighted interior is added; adding the interior to `2^53` first
  would round to 4. In `{0, 2^53, 0, 1, 0, -2^53, 0}` the odd sum is `2^53 + 1 = 2^53` (a tie,
  rounded to even) and then 0, so the result is 0; summing right to left would give 4. The even sum
  is pinned the same way.
- Overflow cases have finite samples and `h` and overflow in exactly one operation: the endpoint
  sum, either interior sum, either scaling by 4 or 2, either of the two additions forming `s`, or
  the product `h * s`. Two of them have a representable exact result (`h * 4 * DBL_MAX / 3` with
  `h = 1/4`, and `DBL_MAX / 2` from `h = DBL_MAX / 4` and `s = 6`): the kernel's range is limited
  by its intermediates, as `spec/simpson.md` states.
- `DBL_TRUE_MIN / 3` rounds to `+0`: underflow is a finite result, not an error.

## Python

Expected values in `test/python/test_simpson.py`, beyond the cases it shares with the C test:

- The Hypothesis test draws odd-length lists (3 to 41 samples) and requires bitwise agreement
  (value and sign of zero) with the same two left-to-right sums from `+0`, the regrouping
  `((y0 + yl) + 4 so) + 2 se` and `(h s) / 3` in Python floats, and `ValueError` exactly when that
  evaluation is not finite.
- The rounding test checks the SIMPSON-B2 bound against the rule evaluated exactly in
  `fractions.Fraction`, on scaled random samples in the normal range (1001 samples, `h = 0.1`), on
  samples near `2^-1000` with `h = 0.1 * 2^-60` (the product with `h` underflows), and on
  `{DBL_TRUE_MIN, 0, 0}` with `h = 1` (the division by 3 underflows to 0).
- The convergence test integrates `exp` on `[0, 1]` against `e - 1` from mpmath at 40 digits, for
  `m = 8, ..., 128` panels. SIMPSON-A2 with `M4 = e` bounds the error by `e h^4 / 180`, and
  `exp'''' > 0` makes it positive. By Euler-Maclaurin the error is
  `(e - 1) h^4 / 180 - (e - 1) h^6 / 1512 + O(h^8)`, so each halving of `h` divides it by
  `16 (1 - (3/4)(180/1512) h^2) + O(h^4)`, about `0.022` below 16 at `h = 1/8` (measured
  `15.978`); SIMPSON-B2 bounds the rounding by about `1.3e-14` against the smallest error, about
  `3.6e-11`, so it moves a ratio by at most about `0.006`. The test allows `0.05`.
