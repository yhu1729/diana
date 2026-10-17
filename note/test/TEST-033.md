---
id: TEST-033
title: Cholesky C test values, rounding pins and failure cases
kind: fact
path:
  - test/c/test_cholesky.c
related: [API-028, TEST-006, TEST-034]
---
`test/c/test_cholesky.c` compares every factor bit for bit and checks that nothing past
`l[n*n - 1]` is written (sentinel 42.0).

- Exact factors: `A = L·Lᵀ` for integer `L` with square-integer diagonals (`n = 1, 3, 4` and a
  20×20 with diagonal 1 to 3 and off-diagonal `i + j - 19`); every sum is an integer below 2⁵³ and
  every root and quotient exact, so the kernel returns `L`. NaN and `±inf` in the strict upper
  triangle of `a` change nothing; a `-0` below the diagonal gives `-0` in `L`.
- Rounding pins: `√2` equals libm's correctly rounded `sqrt(2.0)`; `a = [9, 5; ·, 100]` gives
  `L[1,0] = 5/3 = 0x1.aaaaaaaaaaaabp+0`, where `5·fl(1/3)` would round down; the pivot `1 + 3·2⁻⁵² −
  fl((1 + 2⁻⁵²)²) = 2⁻⁵²` gives `L[1,1] = 2⁻²⁶`, where a fused multiply-add would give `2⁻²⁶·(1 −
  2⁻⁵³)`; with `L[2,0] = L[2,1] = 2⁻²⁷` the pivot `1 − 2⁻⁵⁴ − 2⁻⁵⁴` stays 1 by two ties to even,
  where summing the products first would give `1 − 2⁻⁵³` and `L[2,2] = 1 − 2⁻⁵³`.
- A subnormal pivot `2⁻¹⁰⁷⁴` has the normal root `2⁻⁵³⁷`.
- `DIANA_ERR_SINGULAR`: zero matrix, `-0`, `-1`, `[1 2; 2 1]` (indefinite), `[1 1; 1 1]` (pivot
  exactly 0), a failing last pivot, `1e300 / 2⁻⁵³⁷` overflowing so that the next pivot is `-inf`,
  and `L[2,0] = inf` with `L[1,0] = 0`, so that `L[2,1] = (1 − inf·0)/1` and the pivot of
  column 2 are NaN.
- `DIANA_ERR_ARG` with `l` untouched: each NULL, `n = 0`, `n = 2³²` and `SIZE_MAX` (`n*n` wraps;
  rejected before any access), and NaN, `inf`, `-inf` at each of the six lower-triangle positions
  of a 3×3 matrix.
- Line and branch coverage of `src/cholesky.c` and `src/fp_sqrt.c` is 100% (TEST-006).
