---
id: PROOF-013
title: Norm theorems, their hypotheses and the error bounds
kind: fact
path:
  - spec/norm.md
  - src/norm_1.c
  - src/norm_2.c
  - src/norm_inf.c
related: [PROOF-007, API-037, WP-014, VST-007]
---
The three norms are proved through every layer (`spec/norm.md`), the vectors as lists.

- Layer A, Lean and Rocq: A1 `m·√(1 + Σ_{i≠k} (xᵢ/m)²) = ‖x‖₂` for `m = |xₖ| ≠ 0`, the 2-norm
  kernel in exact arithmetic; A2 `‖x‖∞ ≤ ‖x‖₂ ≤ ‖x‖₁ ≤ n·‖x‖∞`; A3 `‖x‖₁ ≤ √n·‖x‖₂` and
  `‖x‖₂ ≤ √n·‖x‖∞`; A4 to A6 the norm axioms (triangle inequality for equal lengths, absolute
  homogeneity, definiteness) for each of the three.
- Layer B, Rocq and Flocq, every entry finite: B1 the maximum norm is exact and finite; B2
  `|r − ‖x‖₁| ≤ γₙ₋₁·‖x‖₁` for a finite result; B3 the 1-norm is finite when
  `(1 + γₙ₋₁)·‖x‖₁ ≤ DBL_MAX`; B4 `|r − ‖x‖₂| ≤ γₙ₊₅·‖x‖₂ + η` for a finite result,
  `(n + 5)·u < 1`; B5 the 2-norm is finite when `(1 + γₙ₊₄)·‖x‖₂ ≤ DBL_MAX`; B6 `r ≥ ‖x‖∞`, so
  a nonzero vector has a positive 2-norm. `γₖ = k·u/(1 − k·u)`, `u = 2⁻⁵³`, `η = 2⁻¹⁰⁷⁵`.
- Layer C: WP proves memory safety, termination, the status set, when each status can occur,
  `*result` untouched on error and `+0` for `n = 0` (C1, C2), and for the maximum norm its exact
  value (C3); C2 assumes only the `diana_fp_sqrt` contract (CHOLESKY-B1). VST (C4 to C6) proves
  for `n ≥ 1` that each kernel computes the binary64 model with the exact status; C7 to C12 are
  the `diana_fp_finite` and `diana_fp_abs` copies.
- Limits: the bounds are relative to the norm because every term is nonnegative; B4's `γₙ₊₅` is
  about twice the classical `(n/2 + 1)·u`, from `|√z − 1| ≤ |z − 1|`; the `η` of B4 is the
  underflow of the final product, which matters only for a norm near the subnormal range.
