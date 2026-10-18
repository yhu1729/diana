---
id: PROOF-011
title: LU theorems, their hypotheses and the backward error bounds
kind: fact
path:
  - spec/lu.md
  - verification/lean/Diana/Real/LU.lean
  - verification/rocq/theory/Real/LU.v
  - verification/rocq/theory/Float/LU.v
related: [PROOF-007, PROOF-009, PROOF-010, API-032]
---
- One model over a record of operations `ops` (`search`, `swap`, `elim`, `state`, `nstate`):
  `state_nstate`, for any operations, makes the pivoted working matrix after `k` steps the
  unpivoted one of `P_k·A`, and `nstate_dot` gives each entry as the Doolittle recurrence in the
  C's order. Layer A instantiates it at the reals (`rops`), layer B at binary64 (`fops`).
- LU-A1 `product`: with `nstate B k k k ≠ 0` for `k < n`, `Σ_{t<n} lo F i t · up F t j = B[i,j]`,
  `F = nstate B n`. A2 `pivot_product`: with every tested magnitude `ptop A n k ≠ 0`, the same
  for `B = P·A`, `B[i, j] = A[prow i, j]`. A3 `permutation` (any `ops`): pivot rows in `[k, n)`
  and `prow` a bijection of `[0, n)`. A4 `multiplier_bound`: `|L[i,j]| ≤ 1`, with no hypothesis
  (`x/0 = 0` in both provers). A5 `singular` and A6 `nonsingular`: exact partial pivoting stops
  at a zero pivot exactly when `A` is singular.
- B1 `finite_result`, B2 `multiplier_bound`: under `fok`, the C's `DIANA_OK` conditions, every
  entry is finite and `|L̂[i,j]| ≤ 1`.
- B3 `upper_error`, `i ≤ j < n`, `i·u < 1`, `B = P̂·A`:
  `|B[i,j] − Σ_{t<i} L̂[i,t]Û[t,j] − Û[i,j]| ≤ γᵢ·(Σ_{t<i} |L̂[i,t]Û[t,j]| + |Û[i,j]|)
  + (1 + γᵢ)·i·η`.
- B4 `lower_error`, `j < i < n`, `(j + 1)·u < 1`:
  `|B[i,j] − Σ_{t<j} L̂[i,t]Û[t,j] − Û[j,j]L̂[i,j]| ≤ γⱼ₊₁·(Σ_{t<j} |…| + |Û[j,j]L̂[i,j]|)
  + (1 + γⱼ₊₁)·(j + |Û[j,j]|)·η`, `η = 2⁻¹⁰⁷⁵`. Over the matrix this is Higham's Theorem 9.3,
  `|ΔA| ≤ γₙ|L̂||Û|`, plus underflow.
- The B3 and B4 proofs reuse Cholesky's `dot_error` through `Substitution.fdotv` (`dotv_error`)
  and `Substitution.row_error`; `test/python/test_lu.py` checks both bounds in rationals on
  random matrices scaled by 1, `2⁻¹⁰⁰⁰` and `2¹⁰⁰⁰` (TEST-038).
- Not proved: a bound on the growth `|Û|` against `|A|` (up to `2ⁿ⁻¹` with partial pivoting), a
  forward error bound, and that a nonsingular binary64 matrix factors without
  `DIANA_ERR_SINGULAR` or an overflow.
