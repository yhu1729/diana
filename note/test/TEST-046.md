---
id: TEST-046
title: Axpy C test values, rounding pins and failure cases
kind: fact
path:
  - test/c/test_axpy.c
  - src/axpy_unchecked.c
related: [API-018, API-039, TEST-016, TEST-018, TEST-047]
---
`test/c/test_axpy.c` copies each `y` into a buffer of 12 sentinels, runs `diana_axpy`, checks
the status, and checks every entry of `y` bit for bit (a `+0` sign included) against the expected
update, or against the original bytes on every error. Every successful case also runs
`diana_axpy_unchecked` on a second copy and compares all 12 slots by bit pattern, so both write
only `y[0 .. n-1]` and agree where the checked kernel succeeds (TEST-018 for the Euler step).

- Exact: `a = 0.5`, `x = {2, 4, −8}`, `y = {1, −1, 0.25}` gives `{2, 1, −3.75}`, and the update
  by `−0.5` restores `y` (AXPY-A3 holds in binary64 when every operation is exact).
- Signed zero: with `y = {−0, −0, +0, +0}` and `x = {1, −1, 1, −1}`, `a = +0` gives
  `{+0, −0, +0, +0}` and `a = −0` gives `{−0, +0, +0, +0}`, the signed products added; a `+∞`
  entry of `x` with `a = 0` is `DIANA_ERR_ARG`.
- No contraction: `a = 1 + 2⁻⁵²`, `x = 1 − 2⁻⁵²`, `y = −1`: the product `1 − 2⁻¹⁰⁴` rounds to 1
  and the sum is `+0`; a fused multiply-add would give `−2⁻¹⁰⁴` (TEST-016 for the Euler step).
- Underflow: `0.5 · 2⁻¹⁰⁷⁴` is a tie that rounds to even, `+0`; `1.5 · 2⁻¹⁰⁷⁴` rounds up to
  `2⁻¹⁰⁷³`.
- Overflow of finite inputs: the product `2 · DBL_MAX`, the sums `DBL_MAX + DBL_MAX` and
  `−DBL_MAX − DBL_MAX`, and a last component overflowing after two finite ones; `DBL_MAX −
  DBL_MAX` is `+0`, not an error.
- Errors: NULL `x` or `y` (with `n` 2 and 0), NaN and `±∞` as `a` (also for `n = 0`), NaN and
  `+∞` at each of four positions of `x` and NaN and `−∞` at each of `y`, and a non-finite entry
  after an overflowing first component (`DIANA_ERR_ARG`, not `DIANA_ERR_OVERFLOW`).
- `n = 0` with a finite `a` is `DIANA_OK` and leaves `y`, as is the unchecked kernel with a NaN
  `a`; an eight-entry vector is checked against `y[i] + a * x[i]` evaluated by the test itself,
  compiled without contraction.
- `check_raw` cases (unchecked only, a NaN accepted by `isnan`): `0 ± 2·DBL_MAX = ±∞`
  (product), `±(DBL_MAX + DBL_MAX) = ±∞` (sum), `∞ − ∞` and `1 + 0·∞` NaN,
  `(1, 2, DBL_MAX) + (1, 1, DBL_MAX) = (2, 3, +∞)` with the finite components written,
  `(−1, NaN, 0.5) + (2, 1, −∞) = (1, NaN, −∞)`, a NaN `a` giving NaN everywhere, `a = +∞` with
  positive `x` giving `+∞`; each argument error is checked for both kernels.
- The test alone covers every line and branch of `src/axpy.c` and `src/axpy_unchecked.c`
  (TEST-006).
