---
id: PROOF-009
title: Cholesky theorems, their hypotheses and the backward error bound
kind: fact
path:
  - spec/cholesky.md
  - verification/lean/Diana/Real/Cholesky.lean
  - verification/rocq/theory/Real/Cholesky.v
  - verification/rocq/theory/Float/Cholesky.v
related: [PROOF-007, API-028, FP-006]
---
- CHOLESKY-A1 `product`: if every pivot `p_j`, `j < n`, is positive, then
  `Σ_{k<n} L[i,k]·L[j,k] = A[i,j]` for `j <= i < n`. No symmetry is assumed; only `A[i,j]` with
  `j <= i` enters the definition.
- A2 `pivot_pos`: `A` symmetric on the indices below `n` and `xᵀAx > 0` for every `x` with some
  `x_i ≠ 0`, `i < n`, imply every pivot positive. A3 `pos_def`: a symmetric `A` with every pivot
  positive is positive definite. In exact arithmetic the kernel's `DIANA_ERR_SINGULAR` thus means
  "not positive definite".
- B1 `sqrt_contract`: for `x > 0` (IEEE), finite `x` gives a finite `fsqrt x > 0` equal to the
  rounded `√x`, and `+∞` gives `+∞`; this is the `SKIP` contract of `diana_fp_sqrt`.
- B2 `finite_result`: with every entry on or below the diagonal finite and every pivot positive,
  every entry of the binary64 factor is finite.
- B3 `backward_error`: under B2's hypotheses and `(j + 2)·u < 1`, for `j <= i < n`, `|A[i,j] −
  Σ_{k<=j} L̂[i,k]L̂[j,k]| <= γ_{j+2}·Σ_{k<=j} |L̂[i,k]L̂[j,k]| + (1 + γ_{j+2})(j + |L̂[j,j]|)·η`.
  - Below the diagonal the proof gives `γ_{j+1}`; the statement uses `γ_{j+2}` throughout. Over the
    matrix this is Higham's `|ΔA| <= γ_{n+1}·|L̂|·|L̂ᵀ|` (Theorem 10.3) plus underflow.
  - `η = 2⁻¹⁰⁷⁵` bounds the absolute error of each of the `j` products and of the division
    (scaled by `|L̂[j,j]|`); the subtractions and the square root add none (`add_error`; a root of
    a positive binary64 is normal).
  - `test/python/test_cholesky.py` checks the bound in rationals on random matrices scaled by 1,
    `2⁻¹⁰⁰⁰` and `2¹⁰⁰⁰`.
- Not proved: a forward error bound on `L̂`, which depends on the conditioning of `A`, and that a
  positive definite binary64 matrix factors without `DIANA_ERR_SINGULAR` (a nearly singular one
  may not).
