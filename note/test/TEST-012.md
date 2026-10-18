---
id: TEST-012
title: Trapezoidal Python property, rounding-bound and convergence tests
kind: fact
path:
  - test/python/test_trapezoidal.py
related: [TEST-010, TEST-015]
---
`test/python/test_trapezoidal.py` compares the kernel with an independent binary64 evaluation,
checks the TRAPEZOIDAL-B2 rounding bound in exact arithmetic, and checks the TRAPEZOIDAL-A2 error
bound and the second order on `exp`.

- Property (Hypothesis, 500 derandomized examples, no example database): any list of 2 to 40
  floats, NaN and infinities included, and any `h`, passed as a list and as a NumPy array. The
  result must equal the same evaluation in Python floats (halved endpoints, interior left to
  right, product) bit for bit including the sign of zero. When that evaluation is not finite the
  call must raise `FloatOverflowError` ("overflows") if `h` and every sample are finite and a
  plain `ValueError` ("input is not finite") otherwise.
- Rounding: `|r - T| <= gamma_n |h| A + (1 + gamma_(n-1)) |h| eta + eta` with `u = 2^-53`,
  `eta = 2^-1075`, `gamma_k = k u / (1 - k u)` and `T`, `A` in `fractions.Fraction`. Cases: 1000
  samples `uniform(-1, 1) * 2^k`, `k` in `[-20, 20]` (seed 1729), `h = 0.1`; `{DBL_TRUE_MIN, 0}`
  with `h = 1`, where the halving underflows to 0 and the error is exactly `eta`; 100 samples with
  `k` in `[-1000, -990]` (seed 1730) and `h = 0.1 * 2^-60`, where the product underflows. In both
  underflow cases the error exceeds the `gamma_n |h| A` term, so the `eta` terms are needed.
- Convergence: `exp` on `[0, 1]` with `m = 16, 32, ..., 256` panels against `e - 1` from mpmath
  at 40 digits. Each error must lie in `(0, e h^2 / 12]` (TRAPEZOIDAL-A2 with `M2 = e`; positive
  because `exp` is convex), and each halving of `h` must divide it by 4 within `1e-3`. By
  Euler-Maclaurin the ratio is `4 (1 - h^2 / 80) + O(h^4)`, within `2e-4` of 4 for `h <= 1/16`;
  the smallest error, about `2.2e-6`, is far above rounding (about `1e-13`).
