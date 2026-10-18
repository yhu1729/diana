---
id: PROOF-010
title: Substitution theorems, their hypotheses and the error bounds
kind: fact
path:
  - spec/substitution.md
  - verification/lean/Diana/Real/Substitution.lean
  - verification/rocq/theory/Real/Substitution.v
  - verification/rocq/theory/Float/Substitution.v
related: [PROOF-007, PROOF-009, API-030]
---
- SUBSTITUTION-A1 `forward_solve`, A4 `back_solve`: each row of `L·x = b` (or `Lᵀ·x = b`) holds
  for `x = fwd L b` (`bwd L b n`) once its diagonal entry is nonzero; nothing above the diagonal
  is read or assumed.
- A3 `forward_perturb`, A6 `back_perturb`: residuals of `y` bounded by `ρ` give `|x − y| ≤ z`, `z`
  the same solve of `ρ` with the comparison matrix `M(L)` (`|L[i,i]|` on, `−|L[i,k]|` off the
  diagonal), that is `M(L)⁻¹·ρ`. A2 and A5 (uniqueness) are the case `ρ = 0`.
- A7 `cholesky_solve`: with CHOLESKY-A1's hypotheses and symmetry, `bwd L (fwd L b) n` for
  `L = chol A` solves `A·x = b`.
- B1 `forward_backward_error`, row `i`, needs only `x̂ᵢ` finite, `L[i,i]` a nonzero real and
  `(i + 1)·u < 1`:
  `|bᵢ − Σ_{k≤i} L[i,k]x̂ₖ| ≤ γᵢ₊₁·Σ_{k≤i} |L[i,k]x̂ₖ| + (1 + γᵢ₊₁)(i + |L[i,i]|)·η`, with
  `η = 2⁻¹⁰⁷⁵`. Over the matrix this is `(L + ΔL)x̂ = b`, `|ΔL| ≤ γₙ|L|`, plus underflow; the
  subtractions add no absolute term (`add_error`), each product and the division one `η`.
- B3 `back_backward_error`: the same with `n − i` terms, `γₙ₋ᵢ` and `(n − 1 − i + |L[i,i]|)·η`.
- B2 `forward_forward_error`, B4 `back_forward_error`: A3 (A6) applied to B1 (B3) for every row,
  with `n·u < 1`: `|x − x̂| ≤ M(L)⁻¹(γₙ|L||x̂| + underflow)` for the exact solution `x` of the
  system with the binary64 data. The bound is computable (a triangular solve with `M(L)`); it is
  large when `L` is ill-conditioned.
- The proofs reuse `dot_error`, `div_error` and `factor_div` of `Diana.Float.Cholesky`: `fdotv g h`
  is its `fdot` on the two-row matrix `(g, h)`. The back theorems come from the forward ones on
  the mirrored system, through `sum_mirror` and `cmp_mirror`.
- `test/python/test_substitution.py` checks B1 to B4 in rationals on random systems scaled by 1,
  `2⁻¹⁰⁰⁰` and `2¹⁰⁰⁰` (TEST-036).
- Not proved: a bound in terms of a condition number of `L` alone, or that a nonsingular
  binary64 `L` solves without overflow.
