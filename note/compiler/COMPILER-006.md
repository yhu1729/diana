---
id: COMPILER-006
title: What the compiler corpus covers for each kernel
kind: fact
path:
  - test/c/test_compiler.c
related: [COMPILER-005, COMPILER-007, TEST-008, TEST-022]
---
Besides seeded random inputs (COMPILER-007), the corpus runs every public kernel function on the
cases below. Current case lines: `bisection_*` 161, `trapezoidal` 283, `simpson` 284, `euler`
and `euler_unchecked` 248 each, `rk4_stage*` 274 each, `rk4_step*` 270 each, `newton_*` 152,
`cholesky` 248, `forward_substitution` and `back_substitution` 270 each, `lu` 260,
`lu_solve` 292.

- Bisection `init`: NULL state; NaN and an infinity in each argument, a signalling NaN `fa`;
  `a > b`; negative `tol`; `max_iter = 0`; `|a|` or `|b|` one ulp past `DBL_MAX/2` and
  `b = DBL_MAX`; both bracket errors; `tol = -0`; each immediate convergence (`fa` or `fb` `±0`,
  `tol >= b - a`, `a == b`, adjacent endpoints above and below 1, across a binade, among
  subnormals, across 0). Runs printing every step: roots 0.5, `sqrt(2)`, 0.1 (rising and falling
  `f`), a sign function returning `-0` at its root, the 2098-step worst case and its mirror,
  `1e300`, subnormal roots, `ERR_MAXITER` at 5 and 1 steps plus one more `step`, endpoint values
  that overflow. `step` gets NaN, sNaN, `±inf`, `±0`, `±DBL_TRUE_MIN`; `result` NULL pointers.
- Trapezoidal and Simpson: NULL pointers, `n` from 0 to 5, exact and inexact `h`, `h = ±0`, `±0`
  and subnormal samples and `h`, underflow, `DBL_MAX` samples anywhere, `h` up to `DBL_MAX`,
  alternating `±DBL_MAX`, NaN, sNaN and `±inf` in each position and as `h`, the ctest order and
  overflow cases, the 1001-sample affine and cubic cases.
- Euler, checked and unchecked on the same inputs: every argument error, exact and inexact `h`,
  the FMA case, `h = ±0` with signed-zero `y`, underflow ties, `DBL_MAX + 1`, product and sum
  overflow, cancellation, first and last component failing, NaN, sNaN and infinities in each
  position of `y` and `f` and in `h`.
- RK4 stage and step, checked and unchecked: every argument error (stages 0, 1, 5, -2), stages 2
  to 4 with exact and inexact `h`, `h = ±0`, the `h = 3 * 2^-1074` coefficient tie,
  `h = DBL_MAX`, both FMA cases, the slope-sum order case, overflow in each operation,
  cancellation, first and last component failing, non-finite values in every position.
- Newton: every `init` error; `step` with NaN, sNaN, `±inf` `f` and `f'`, `±0` `f'`, `±0` `f`
  (also with zero or NaN `f'`), tiny, underflowing, tie and overflowing corrections, an
  overflowing iterate; runs for `sqrt(2)` (with `tol`, from 1, the `tol = 0` two-cycle), exact
  linear roots, the cube root of 10, the double root of `x^2` (digest only, 539 steps), the
  two-cycle of `x^3 - 2x + 2` from 0, a flat `f`, `max_iter = 1`, a root at `1e300`, an
  overflowing square, and `x^2 + 1`, which has no real root.
- Cholesky: every argument error (NULL pointers, `n = 0`, `n = 2^32` and `SIZE_MAX`, whose `n * n`
  overflows), exact factors, NaN and infinities above the diagonal, a signed-zero diagonal, the
  FMA, subtraction-order and division pins, a subnormal pivot, `DBL_MAX` entries, each kind of
  non-positive pivot (zero, `-0`, negative, indefinite, semidefinite, last, overflow to `-inf`,
  NaN), and NaN, sNaN and `±inf` at each lower-triangle position of a 3×3 matrix; the random
  matrices (`n` from 1 to 8) alternate raw entries with diagonally dominant ones, which succeed.
- Forward and back substitution, both on the same inputs: every argument error (each NULL,
  `n = 0`, `n = 2^32`, `SIZE_MAX`), exact solutions for both kinds of right-hand side, NaN and
  infinities above the diagonal, signed-zero results, the FMA, subtraction-order and division
  pins of each kernel, an underflow tie and a subnormal result, `DBL_MAX` entries, each overflow
  (quotient, product, difference, NaN from two infinite products), `+0` and `-0` at each diagonal
  position with and without a NaN in `b`, and NaN, sNaN and `±inf` at each lower-triangle position
  of a 3×3 `L` and each position of `b`; the random systems (`n` from 1 to 8) alternate raw entries
  with diagonally dominant ones of random sign.
- LU: every argument error (each NULL, `n = 0`, `n = 2^32`, `SIZE_MAX`), a 1×1 matrix, the ctest
  pivoting, tie, division, FMA and subtraction-order pins, a signed-zero multiplier, a product
  that underflows, `DBL_MAX` entries, each kind of zero pivot (all zero, `-0`, a zero column,
  rank one, the last pivot), an update overflowing in the first and in a later column, and NaN,
  sNaN and `±inf` at each position of a 3×3 matrix; the random matrices (`n` from 1 to 8)
  alternate raw entries with entries bounded by `DBL_MAX/2`.
- LU solve: every argument error (each NULL, `n = 0`, `n = 2^32`, `SIZE_MAX`), a 1×1 system, the
  factor of `[2 1 1; 4 -6 0; -2 7 2]`, the interchange order and pivot rows below `k`, a
  signed-zero result, the FMA and subtraction-order pins of each solve, the division pin, an
  underflow tie and a subnormal result, `DBL_MAX` entries, each overflow (forward difference,
  forward NaN, quotient, product, difference), `+0` and `-0` at each diagonal position with and
  without a NaN in `b` or a pivot row of `n`, pivot rows `n` and `SIZE_MAX` at each position, and
  NaN, sNaN and `±inf` at each position of a 3×3 `lu` and of `b`; the random systems (`n` from 1
  to 8) alternate raw factors and pivot rows with the output of `diana_lu` on bounded matrices.
