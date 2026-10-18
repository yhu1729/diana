---
id: TEST-037
title: LU C test values, rounding pins and failure cases
kind: fact
path:
  - test/c/test_lu.c
related: [API-032, TEST-006, TEST-038]
---
`test/c/test_lu.c` compares every factor and pivot row bit for bit and checks that nothing past
`lu[n*n - 1]` or `piv[n - 1]` is written (sentinels 42.0 and 77).

- Pivoting: `[1 2; -3 4]` pivots on row 1 (`L[1,0] = fl(1/-3)`); `[1 1; -1 1]` keeps row 0 on a
  tie; the 3×3 `[2 2 1; -3 1 0; 3 -9 6]` takes row 1, the first of two of magnitude 3, then
  interchanges rows 1 and 2 with their stored multipliers, ending with `U[2,2] = 3`.
- Exact factors: `A = Pᵀ·L·U` for `n = 20` with `L` in eighths of magnitude below 1 and nonzero
  (a zero multiplier below a negative pivot would come out `-0`), integer `U` and the row order
  `7i + 3 mod 20`, so partial pivoting recovers `P` and every operation is exact; the expected
  `piv` replays the interchanges.
- Rounding pins: `3/5 = 0x1.3333333333333p-1` where `3·fl(1/5)` rounds up; `2 − fl((1 − 2⁻⁵³)(1 +
  2⁻⁵²)) = 1` where a fused multiply-add gives `1 − 2⁻⁵³`; `U[2,2] = 1 − 2⁻⁵⁴ − 2⁻⁵⁴ = 1` by two
  ties to even, where summing the products first gives `1 − 2⁻⁵³`.
- Small values: `-0/2 = -0` and subnormal entries are kept; `2⁻⁵³⁸·3·2⁻⁵³⁷` underflows to
  `2⁻¹⁰⁷³`, not an error.
- `DIANA_ERR_SINGULAR`: `[0]`, a `-0` pivot column, a zero first column, `[1 2; 2 4]` and the 3×3
  `1, …, 9`, whose last pivot is exactly 0. `DIANA_ERR_OVERFLOW` from a finite `a`, found after
  `lu` is written: `DBL_MAX − 1·(−DBL_MAX)` at the first update, and a 3×3 whose fourth update
  overflows.
- `DIANA_ERR_ARG` with `lu` and `piv` untouched: each NULL, `n = 0`, `n = 2³²` and `SIZE_MAX`,
  and NaN, `inf`, `-inf` at each of the nine positions of a 3×3 matrix.
- Line and branch coverage of `src/lu.c` is 100% (TEST-006).
