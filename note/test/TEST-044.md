---
id: TEST-044
title: Norm C test values, rounding pins and failure cases
kind: fact
path:
  - test/c/test_norm.c
related: [API-037, TEST-045]
---
`test/c/test_norm.c` runs each case against the kernels named, checks the status, the bits of the
result (a `+0` sign included) and that `*result` keeps the sentinel 42 on every error.

- Exact: `{3, −4, 1}` has 1-norm 8 and maximum norm 4; `{3, −4}` and `{−4, 3}` have 2-norm 5
  (`s = 1 + (3/4)² = 1.5625`, `√s = 1.25`); `{−7}` gives 7 for all three; empty and `±0` vectors
  give `+0`.
- Order pins: `{2⁵³, 1, −1}` has 1-norm `2⁵³`, each `2⁵³ + 1` rounding to even; sixteen `2⁻²⁷` and
  a 1 have 2-norm 1 wherever the 1 is, since each `2⁻⁵⁴` added to `s = 1` is below half an ulp
  (index order with the 1 last would give `1 + 2⁻⁵¹`); `{4, −4}` gives `4·fl(√2)`.
- Scaling: the 2-norm of `{−DBL_MAX}` is `DBL_MAX`, of `{1e300, −1e300}` and `{1e-200, 1e-200}`
  the scaled `fl(√2)` products, of `{2⁻¹⁰⁷⁴}` and `{2⁻¹⁰⁷⁴, −2⁻¹⁰⁷⁴}` `2⁻¹⁰⁷⁴`, and of
  `{DBL_MAX, 2⁻¹⁰⁷⁴}` `DBL_MAX` (the quotient underflows to `+0`).
- Overflow: `{DBL_MAX, −DBL_MAX}` overflows the 1- and 2-norm, not the maximum norm;
  `DBL_MAX + 2⁹⁷⁰` is halfway to `2¹⁰²⁴` and overflows the 1-norm, `DBL_MAX + 2⁹⁶⁹` does not;
  `{DBL_MAX, DBL_MAX·2⁻²⁶}` has 2-norm `DBL_MAX` because `√(1 + 2⁻⁵²)` rounds to 1, though the
  exact norm rounds to `2¹⁰²⁴`.
- Errors: NULL `x` (with `n` 2 and 0) and NULL `result`; NaN and `±∞` at each of four positions,
  `{DBL_MAX, DBL_MAX, NaN}` (argument error after the sum overflows) and `{0, −∞}`.
- The test alone covers every line and branch of the three sources (TEST-006).
