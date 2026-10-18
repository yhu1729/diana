---
id: PROOF-012
title: LU solve theorems, their hypotheses and the residual bounds
kind: fact
path:
  - spec/lu_solve.md
  - verification/lean/Diana/Real/LUSolve.lean
  - verification/rocq/theory/Real/LUSolve.v
  - verification/rocq/theory/Float/LUSolve.v
related: [PROOF-007, PROOF-010, PROOF-011, API-034]
---
- The model: `solution F p b n = bwd Uᵀ (fwd (lo F) (b ∘ pperm p n)) n`, Substitution's solves on
  the packed factor, with `pperm p (k + 1) i = pperm p k (τ_{k, p k} i)` the interchanges in
  order. `pperm_perm` makes LU's row order `perm` the interchanges of its pivot rows, for any
  number type, so the solve meets the factorization without a separate permutation model.
- LU-SOLVE-A1 `interchange_permutation`: with `p k < n`, `pperm p n` is a bijection of `[0, n)`.
  A2 `factor_solve`: with `F i i ≠ 0`, `L·U·x = P·b`. A3 `lu_solve`: with every tested pivot
  magnitude `ptop A n k ≠ 0`, `A·x = b` for `x = solution (lu A n) (pivots A n) b n`.
- B1 `forward_backward_error`, `i·u < 1`, `c = P·b`:
  `|cᵢ − Σ_{k<i} L̂[i,k]ŷₖ − ŷᵢ| ≤ γᵢ·(Σ_{k<i} |L̂[i,k]ŷₖ| + |ŷᵢ|) + (1 + γᵢ)·i·η =: αᵢ`.
  B2 `back_backward_error` is SUBSTITUTION-B3 for `Uᵀ`: `|ŷᵢ − Σ_{k≥i} Û[i,k]x̂ₖ| ≤ βᵢ`, with
  `γₙ₋ᵢ` and the underflow term `(1 + γₙ₋ᵢ)(n − 1 − i + |Û[i,i]|)·η`.
- B3 `factor_residual`, every `ŷ`, `x̂` finite, `n·u < 1`:
  `|cᵢ − (L̂·Û·x̂)ᵢ| ≤ αᵢ + Σ_{t≤i} |L̂[i,t]|·βₜ`. B4 `lu_residual`, with `fok` of diana_lu too and
  `B = P̂·A`: `|cᵢ − (B·x̂)ᵢ| ≤ αᵢ + Σ_{t≤i} |L̂[i,t]|·βₜ + Σⱼ Eᵢⱼ·|x̂ⱼ|`, `Eᵢⱼ` the bound of
  LU-B3 or B4. To first order in `u` this is Higham's Theorem 9.4,
  `(A + ΔA)·x̂ = b`, `|ΔA| ≤ (3γₙ + γₙ²)|L̂||Û|`, as a residual bound with underflow terms.
- `test/python/test_lu_solve.py` checks B1 to B4 in rationals on random systems with `n` up to
  20, scaled by 1, `2⁻¹⁰⁰⁰` and `2¹⁰⁰⁰` (TEST-040).
- Not proved: a forward error bound (it needs `A⁻¹`, through LU-A6 or a condition number), a
  bound on the growth `|Û|` (PROOF-011), and that a solve on a successful binary64 factor never
  overflows.
