---
id: TEST-046
title: Axpy C test values, rounding pins and failure cases
kind: fact
path:
  - test/c/test_axpy.c
related: [API-039, TEST-016, TEST-047]
---
`test/c/test_axpy.c` copies each `y` into a local buffer, runs `diana_axpy`, checks the status,
and checks every entry of `y` bit for bit (a `+0` sign included) against the expected update, or
against the original bytes on every error.

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
- `n = 0` with a finite `a` is `DIANA_OK` and leaves `y`; an eight-entry vector is checked
  against `y[i] + a * x[i]` evaluated by the test itself, compiled without contraction.
- The test alone covers every line and branch of `src/axpy.c` (TEST-006).
