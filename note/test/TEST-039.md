---
id: TEST-039
title: LU solve C test values, rounding pins and failure cases
kind: fact
path:
  - test/c/test_lu_solve.c
related: [API-034, TEST-006, TEST-035, TEST-037, TEST-040]
---
`test/c/test_lu_solve.c` compares every solution bit for bit and checks that nothing past
`x[n - 1]` is written (sentinel 42.0).

- Exact solutions: a packed factor with integer `L`, integer `U` with diagonal `±1, ±2, ±4` and
  pivot rows `j + 3j mod (20 − j)`, `n = 20`, and a right-hand side built from a nonzero integer
  `x` by undoing the interchanges, so every operation is exact (an exact zero over a negative
  pivot would come out `-0`). The factor `diana_lu` writes for `[2 1 1; 4 -6 0; -2 7 2]`
  (`L` in halves, `piv = (1, 1, 2)`) gives `x = (1, -2, 3)` for `b = (3, 16, -10)`; the `n = 20`
  construction of TEST-037 with power-of-two pivots, through `diana_lu`, gives `x` exactly.
- Interchanges: `piv = (1, 2, 2)` turns `(1, 2, 3)` into `(2, 3, 1)` with the identity factor,
  where the reverse order gives `(3, 1, 2)`; `(0, 0, 1)`, with pivot rows below `k`, is accepted.
- Rounding pins: `5/3 = 0x1.aaaaaaaaaaaabp+0`; a zero `b` gives `-0` over a negative pivot;
  `2⁻¹⁰⁷⁴ / 2` rounds to `+0`; `(1 + 3·2⁻⁵²) − fl((1 + 2⁻⁵²)²) = 2⁻⁵²` in each solve, where a
  fused multiply-add gives `2⁻⁵² − 2⁻¹⁰⁴`; `2⁻⁵³ − (−1) − (−2⁻⁵³) = 1` by two ties in each solve
  (forward subtracts `L[2,0]·y₀` first, back `U[0,2]·x₂`).
- Agreement: for `n = 1` to 20, random factors (diagonal plus 4) and random `piv[k] < n`, the
  solve equals `diana_forward_substitution` with the unit lower factor on `P·b` followed by
  `diana_back_substitution` with the transposed upper factor, bit for bit.
- `DIANA_ERR_SINGULAR` with `x` untouched: `+0` and `-0` at the first, middle and last diagonal
  position; a NaN in `b` or in `lu`, or `piv[1] = 3`, with a zero diagonal is `DIANA_ERR_ARG`.
- `DIANA_ERR_ARG` with `x` untouched: each NULL, `n = 0`, `n = 2³²` and `SIZE_MAX`; NaN, `inf`,
  `-inf` at each of the nine positions of a 3×3 `lu` and each position of `b`; `piv[k] = 3` and
  `SIZE_MAX` at each position.
- `DIANA_ERR_ARG` from overflow: forward `−DBL_MAX − 1·DBL_MAX` and `0 − (−inf) − inf`; back
  `1e300 / 1e-300`, a product `1e300·1e300` and `DBL_MAX − (−1)·DBL_MAX`.
- Line and branch coverage of `src/lu_solve.c` is 100% (TEST-006).
