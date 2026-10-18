---
id: TEST-015
title: Simpson Python property, rounding-bound and convergence tests
kind: fact
path:
  - test/python/test_simpson.py
related: [TEST-013, TEST-012]
---
`test/python/test_simpson.py` compares the kernel with an independent binary64 evaluation,
checks the SIMPSON-B2 rounding bound in exact arithmetic, and checks the SIMPSON-A2 error bound and
the fourth order on `exp`.

- Property (Hypothesis, 500 derandomized examples, no example database): lists of odd length
  `2p + 1`, `p` in 1..20 (3 to 41 samples), of any floats, and any `h`, as a list and as a NumPy
  array. The result must equal, bit for bit including the sign of zero, Python's
  `h * (((y0 + yl) + 4.0 * so) + 2.0 * se) / 3.0` with both sums left to right from `0.0`. When
  that value is not finite the call must raise `FloatOverflowError` ("overflows") if `h` and every
  sample are finite and a plain `ValueError` ("input is not finite") otherwise.
- Rounding: `|r - h S'/3| <= gamma_(p+5) |h| A / 3 + (1 + u) eta / 3 + eta`, `p = (n - 1)/2`,
  `A = |y0 + yl| + 4 sum|odd| + 2 sum|even|`, in `fractions.Fraction`. Cases: 1001 samples
  `uniform(-1, 1) * 2^k`, `k` in `[-20, 20]` (seed 1729), `h = 0.1`; 101 samples with `k` in
  `[-1000, -990]` (seed 1730) and `h = 0.1 * 2^-60`, where the product underflows; and
  `{DBL_TRUE_MIN, 0, 0}` with `h = 1`, where the division by 3 underflows to 0. In both underflow
  cases the error exceeds the `gamma` term, so the `eta` terms are needed.
- Convergence: `exp` on `[0, 1]` with `m = 8, 16, ..., 128` panels against `e - 1` from mpmath at
  40 digits. Each error must lie in `(0, e h^4 / 180]` (SIMPSON-A2 with `M4 = e`; positive since
  `exp'''' > 0`), and each halving of `h` must divide it by 16 within `0.05`. By Euler-Maclaurin
  the ratio is `16 (1 - (3/4)(180/1512) h^2) + O(h^4)`, about `0.022` below 16 at `h = 1/8`
  (measured 15.978, then 15.994, 15.999, 16.000). SIMPSON-B2 bounds the rounding at `h = 1/128`
  by about `1.3e-14` against an error of about `3.6e-11`, which moves a ratio by at most about
  `0.006`.
