---
id: TEST-035
title: Substitution C test values, rounding pins and failure cases
kind: fact
path:
  - test/c/test_substitution.c
related: [API-030, TEST-006, TEST-036]
---
`test/c/test_substitution.c` compares every solution bit for bit and checks that nothing past
`x[n - 1]` is written (sentinel 42.0); each case runs both kernels unless noted.

- Exact solutions: integer `L` with power-of-two diagonal and integer `x` (`n = 1, 3`, and 24 with
  off-diagonal entries `(7i + 3j) mod 5 − 2`), `b = L·x` or `Lᵀ·x` computed exactly; NaN and
  `±inf` in the strict upper triangle change nothing. `diana_cholesky` of
  `[[4, 2, -2], [2, 10, 5], [-2, 5, 21]]` and both solves give `x = (1, -2, 3)` for
  `b = (-6, -3, 51)`.
- Rounding pins: `5/3 = 0x1.aaaaaaaaaaaabp+0`, where `5·fl(1/3)` would round down; a zero `b`
  gives `-0` over a negative and `+0` over a positive diagonal; `(1 + 3·2⁻⁵²) − fl((1 + 2⁻⁵²)²) =
  2⁻⁵²`, where a fused multiply-add gives `2⁻⁵² − 2⁻¹⁰⁴`; `2⁻⁵³ − (−1) − (−2⁻⁵³) = 1` by two ties
  to even, where the other subtraction order gives `1 + 2⁻⁵²` (forward subtracts `L[2,0]·x₀`
  first, back `L[2,0]·x₂`); `2⁻¹⁰⁷⁴ / 2` rounds to `+0` and `2⁻¹⁰⁷⁴ / 0.5` is exact.
- Mirror: for `n = 1` to 24 and seeded random `L` (entries in `[-0.5, 0.5)`, diagonal plus 4) and
  `b`, back substitution equals forward substitution on the mirrored system bit for bit.
- `DIANA_ERR_SINGULAR` with `x` untouched: `+0` and `-0` diagonals at the first, middle and last
  position; a NaN in `b` or below the diagonal with a zero diagonal is `DIANA_ERR_ARG` instead.
- `DIANA_ERR_ARG` with `x` untouched: each NULL, `n = 0`, `n = 2³²` and `SIZE_MAX`, and NaN,
  `inf`, `-inf` at each of the six lower-triangle positions of a 3×3 `L` and each position of `b`.
- `DIANA_ERR_ARG` from overflow: `1e300 / 1e-300`, a product `1e300·1e300`, a difference
  `DBL_MAX − (−DBL_MAX)`, and `0 − (−inf) − inf = NaN` from two overflowing products.
- Line and branch coverage of `src/forward_substitution.c` and `src/back_substitution.c` is 100%
  (TEST-006).
