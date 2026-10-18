---
method: lu_solve
kernel: src/lu_solve.c
model: >
  solution F p b n : ℝ^n, the solution of A·x = b from a packed factor F of P·A = L·U (L strictly
  below the diagonal, its unit diagonal not stored, U on and above it) and pivot rows p: c = P·b,
  row i of P·b being entry pperm p n i of b, where P interchanges rows k and p k for
  k = 0, …, n − 1 in that order; then y = fwd (lo F) c, the forward substitution with the unit
  lower-triangular L, and x = bwd Uᵀ y n, the back substitution with U read as the transpose of
  the lower-triangular fun k i => F i k (Diana.Real.Substitution). The binary64 model moves the
  entries of b exactly, evaluates yᵢ = cᵢ − F[i, 0]·y₀ − … − F[i, i − 1]·yᵢ₋₁ with no division
  (fforward), and xᵢ = (yᵢ − F[i, n − 1]·xₙ₋₁ − … − F[i, i + 1]·xᵢ₊₁) / F[i, i] for
  i = n − 1, …, 0, the products subtracted in the order their unknowns were computed
  (fsolution, Substitution.fbwd), each operation rounded to nearest-even (no fused
  multiply-add); the C stores F column-major, lu[i + k·n] = F[i, k], and p k = piv[k].
hypothesis:
  - "H1: F is a real n×n matrix given by its entries F i k, p a function from row to pivot row, b a real vector. A1 takes p k < n for k < n; A2 takes F i i ≠ 0 for i < n; A3 takes A with the pivot magnitude of every step k < n nonzero, as LU-A2, and solves with lu A n and its pivot rows"
  - "H2 (float layers): the entries are arbitrary binary64 values; B1 takes the computed yᵢ finite and i·u < 1, B2 the computed xᵢ finite, F[i, i] a nonzero real and (n − i)·u < 1, u = 2⁻⁵³; B3 takes every yᵢ and xᵢ finite and no zero on the diagonal (the C's DIANA_OK) and n·u < 1; B4 takes in addition the DIANA_OK conditions of diana_lu (LU-B1 to B4) and solves with its factor and pivot rows"
theorem:
  - id: LU-SOLVE-A1
    layer: A
    informal: "the interchanges form a permutation: if every pivot row p k, k < n, is below n, in any order, then i ↦ pperm p n i maps [0, n) onto [0, n) one to one, so P·b is a reordering of b"
    lean: Diana.Real.LUSolve.interchange_permutation
    rocq: Diana.Real.LUSolve.interchange_permutation
  - id: LU-SOLVE-A2
    layer: A
    informal: "the solve with a packed factor: if F i i ≠ 0 for i < n, then x = solution F p b n satisfies Σ_{t<n} L[i, t]·Σ_{j<n} U[t, j]·xⱼ = b_{pperm p n i} for i < n, that is L·U·x = P·b, L unit lower triangular and U upper triangular from F"
    lean: Diana.Real.LUSolve.factor_solve
    rocq: Diana.Real.LUSolve.factor_solve
  - id: LU-SOLVE-A3
    layer: A
    informal: "solving with the factors of partial pivoting: if the pivot magnitude of every step k < n of A is nonzero, then x = solution (lu A n) (pivots A n) b n satisfies Σ_{j<n} A[i, j]·xⱼ = bᵢ for i < n: diana_lu followed by diana_lu_solve solves A·x = b in exact arithmetic (LU-A2 with A2, the row order being the interchanges of the pivot rows)"
    lean: Diana.Real.LUSolve.lu_solve
    rocq: Diana.Real.LUSolve.lu_solve
  - id: LU-SOLVE-B1
    layer: B
    informal: >
      backward error of the forward solve, row i: if the binary64 ŷᵢ is finite and i·u < 1,
      then with c = P·b, |cᵢ − Σ_{k<i} F[i, k]·ŷₖ − ŷᵢ| ≤ γᵢ·(Σ_{k<i} |F[i, k]·ŷₖ| + |ŷᵢ|)
      + (1 + γᵢ)·i·η, γₖ = k·u/(1 − k·u), η = 2⁻¹⁰⁷⁵ (underflow in the products): ŷ solves
      (L + ΔL)·ŷ = P·b with |ΔL| ≤ γₙ·|L|, up to underflow.
    rocq: Diana.Float.LUSolve.forward_backward_error
  - id: LU-SOLVE-B2
    layer: B
    informal: >
      backward error of the back solve, row i < n: if the binary64 x̂ᵢ is finite, F[i, i] is a
      nonzero real and (n − i)·u < 1, then |ŷᵢ − Σ_{i≤k<n} F[i, k]·x̂ₖ|
      ≤ γₙ₋ᵢ·Σ_{i≤k<n} |F[i, k]·x̂ₖ| + (1 + γₙ₋ᵢ)·(n − 1 − i + |F[i, i]|)·η, SUBSTITUTION-B3
      with U as the transpose of a lower-triangular matrix.
    rocq: Diana.Float.LUSolve.back_backward_error
  - id: LU-SOLVE-B3
    layer: B
    informal: >
      residual of the factored system: if every ŷᵢ and x̂ᵢ, i < n, is finite, no F[i, i] is zero
      and n·u < 1 (the C's DIANA_OK), then |(P·b)ᵢ − (L·U·x̂)ᵢ| ≤ αᵢ + Σ_{t≤i} |L[i, t]|·βₜ for
      i < n, αᵢ and βₜ the bounds of B1 and B2, L and U the triangles of the binary64 factor
      read as reals.
    rocq: Diana.Float.LUSolve.factor_residual
  - id: LU-SOLVE-B4
    layer: B
    informal: >
      residual of the solve with the factors of diana_lu: if diana_lu returns DIANA_OK on A
      (LU-B1 to B4), the solve with its factor and pivot rows has every ŷᵢ and x̂ᵢ finite and
      n·u < 1, then for B = P̂·A and i < n, |(P̂·b)ᵢ − (B·x̂)ᵢ| ≤ αᵢ + Σ_{t≤i} |L̂[i, t]|·βₜ
      + Σ_{j<n} Eᵢⱼ·|x̂ⱼ|, Eᵢⱼ the bound of LU-B3 (i ≤ j) or LU-B4 (i > j) on |B − L̂·Û|ᵢⱼ: the
      componentwise form of Higham's (A + ΔA)·x̂ = b, |ΔA| ≤ (3γₙ + γₙ²)·|L̂|·|Û| (Theorem
      9.4), as a residual bound with the underflow terms.
    rocq: Diana.Float.LUSolve.lu_residual
  - id: LU-SOLVE-C1
    layer: C
    informal: >
      ACSL contract in src/lu_solve.c, Frama-C WP float model with RTE: memory safety (only
      lu[0 .. n·n−1], piv[0 .. n−1] and b[0 .. n−1] are read, only x[0 .. n−1] is written, x
      separate from lu, piv and b), no UB, no wrap of the size_t indices i + k·n, every x[piv[k]]
      in bounds, termination of all ten loops, a status in {DIANA_OK, DIANA_ERR_ARG,
      DIANA_ERR_SINGULAR, DIANA_ERR_OVERFLOW}, any status other than DIANA_ERR_ARG only for
      non-NULL pointers with
      n ≥ 1 and n·n ≤ SIZE_MAX, DIANA_ERR_ARG with x untouched when an entry of lu or b is not
      finite or a pivot row is not below n, x untouched on DIANA_ERR_SINGULAR, and every x[w]
      finite on DIANA_OK.
    acsl: src/lu_solve.c
  - id: LU-SOLVE-C2
    layer: C
    informal: >
      diana_lu_solve computes the binary64 model (VST, AArch64 macOS Clight AST): for lu pointing
      to n·n readable doubles, piv to n readable size_t, b to n readable and x to n writable
      doubles, held by separate data_at, with n ≥ 1 and n·n ≤ 2⁶⁴ − 1, it returns DIANA_OK
      exactly when every entry of lu and b is finite, every pivot row is below n, no diagonal
      entry compares equal to 0.0 and every ŷᵢ and x̂ᵢ is finite, and then x holds x̂;
      DIANA_ERR_ARG with x unchanged when an entry is not finite or a pivot row is not below n;
      DIANA_ERR_SINGULAR with x unchanged when they pass and a diagonal entry is ±0; otherwise
      DIANA_ERR_OVERFLOW with x holding ŷ₀, …, ŷᵢ₋₁ and the rest of P·b, ŷᵢ the first entry of the
      forward solve that is not finite, or ŷ₀, …, ŷᵢ and x̂ᵢ₊₁, …, x̂ₙ₋₁, x̂ᵢ the first entry of
      the back solve from the bottom that is not finite. The NULL, n = 0 and overflowing-n paths
      are C1.
    rocq: Diana.VST.LUSolve.body_diana_lu_solve
  - id: LU-SOLVE-C3
    layer: C
    informal: >
      the copy of diana_fp_finite in the Clight AST of lu_solve implements its IEEE semantics,
      as CHOLESKY-C4 (VST, AArch64 macOS Clight AST).
    rocq: Diana.VST.LUSolve.body_diana_fp_finite
---
# lu_solve

Solve `A·x = b` from the LU factorization `P·A = L·U` that `diana_lu` writes. The kernel
`diana_lu_solve(lu, piv, n, b, x)` reads the packed factor from `lu` (`n·n` doubles,
column-major, `lu[i + k·n]`: `L` strictly below the diagonal with its unit diagonal not stored,
`U` on and above it), the pivot rows from `piv` (`n` values of `size_t`) and the right-hand side
from `b`, and writes `x` to a separate buffer of `n` doubles. `diana_lu` then `diana_lu_solve`
solves `A·x = b` (A3).

## Operation order

The binary64 model, and every layer that follows it, is the order of the C:

1. Reject NULL pointers, `n = 0` and an `n` whose `n·n` does not fit in `size_t`; check every
   entry of `lu` in linear order with `diana_fp_finite`, then every `piv[k] < n`, then every
   `b[i]` with `diana_fp_finite`, then every diagonal entry with `lu[i + i·n] == 0.0`. A
   non-finite entry or a pivot row of `n` or more is `DIANA_ERR_ARG`, a zero (or `−0`) diagonal
   entry `DIANA_ERR_SINGULAR`; all leave `x` untouched, and an argument error wins over a zero
   diagonal.
2. `x[i] = b[i]` for every `i`, then for `k = 0, …, n − 1` interchange `x[k]` and `x[piv[k]]`
   through a temporary (an entry with itself when `piv[k] = k`): `x` holds `c = P·b`, an exact
   reordering of `b` (A1).
3. Forward, for `i = 0, …, n − 1`: `s = x[i]`, `s = s − lu[i + k·n]·x[k]` for `k = 0, …, i − 1`,
   each product rounded before the subtraction, with no division by the unit diagonal; if `s` is
   not finite, return `DIANA_ERR_OVERFLOW` (every input is finite by now); else `x[i] = s`.
4. Back, for `i = n − 1, …, 0`: `s = x[i]`, `s = s − lu[i + k·n]·x[k]` for `k = n − 1` down to
   `i + 1`, `r = s / lu[i + i·n]`; if `r` is not finite, return `DIANA_ERR_OVERFLOW`; else
   `x[i] = r`.

The forward and back solves are `diana_forward_substitution` with the unit lower factor and
`diana_back_substitution` with the transposed upper factor bit for bit, as the division by one
the former performs is exact on a finite value. A finite `s` or `r` certifies its row, as in the
substitution kernels, so every entry is finite on `DIANA_OK`.

## Proof sketch

- **A1**: `pperm p (k + 1) i = pperm p k (τ_{k, p k}(i))`, with the transposition `τ` of
  `Diana.Real.LU`; its inverse `ipperm` composes the same transpositions in the other order
  (`pperm_ipperm`), each maps `[0, n)` to itself when `p k < n` (`pperm_range`), and `pperm` is
  injective (`pperm_inj`). The row order of the factorization is the interchanges of its pivot
  rows for any number type (`pperm_perm`: `perm o n A k = pperm (pivot … ) k`).
- **A2**: `Σ_{j<n} U[t, j]·xⱼ = yₜ` for each `t < n` by `Substitution.back_solve` on the
  transpose of `U` (the entries left of the diagonal are zero), then
  `Σ_{t≤i} L[i, t]·yₜ = cᵢ` by `Substitution.forward_solve` with `L[i, i] = 1`.
- **A3**: with `i₀ = iperm i`, `prow i₀ = i`, LU-A2 turns `Σⱼ A[i, j]·xⱼ` into
  `Σₜ L[i₀, t]·Σⱼ U[t, j]·xⱼ`, which A2 makes `b_{pperm i₀} = b_{prow i₀} = bᵢ`; the diagonal of
  `U` is nonzero by `LU.lu_diag_nonzero`.
- **B1**: `fforward_eq`: `ŷᵢ` is `Substitution.fdotv` of row `i`, so `Diana.Float.LU.dotv_error`
  gives the factor `G`, `|G − 1| ≤ γᵢ`, as in LU-B3.
- **B2**: SUBSTITUTION-B3 (`back_backward_error`) with `L k i = F[i, k]`; `fsolution` is
  `Substitution.fbwd` of that matrix on `ŷ` by definition.
- **B3**: with `wₜ = (U·x̂)ₜ` (`up_row`), `cᵢ − Σ_{t≤i} L[i, t]·wₜ = (cᵢ − Σ_{t<i} L[i, t]·ŷₜ −
  ŷᵢ) + Σ_{t<i} L[i, t]·(ŷₜ − wₜ) + (ŷᵢ − wᵢ)`, bounded by B1 and B2 row by row.
- **B4**: `(L̂·Û)ᵢⱼ` is the sum of LU-B3 or LU-B4 (`factor_product`), so
  `(P̂·b)ᵢ − (B·x̂)ᵢ = ((P̂·b)ᵢ − (L̂·Û·x̂)ᵢ) + Σⱼ ((L̂·Û)ᵢⱼ − Bᵢⱼ)·x̂ⱼ`, B3 and LU-B3/B4; the pivot
  rows of the C are `fpivots`, whose interchanges are `Diana.Float.LU.fprow` (`pperm_perm`).
- **C1**: the `/*@ ... */` annotations in `src/lu_solve.c`. The validation loops carry "every
  entry or pivot row checked so far is valid", which gives the interchange loop `piv[k] < n`
  for its index `x[p]`; the index bounds `i + k·n < n·n` use the lemma `column_end` and an
  assertion `0 <= n * (n - 1 - k)` (or `i`), as in CHOLESKY-C1 (WP-011); the back loop carries
  "every entry written so far is finite".
- **C2**: the four validation loops as in LU-C2 and SUBSTITUTION-C3; the copy loop keeps `x` as
  `lpre bl ox n i` (`VST/Matrix.v`); the interchange loop keeps `x` as the list of
  `c_c pl bl k`, `b` after `k` interchanges, and `swap_step` turns the two stores into the next
  one; the forward loop keeps `x` as `lpre` of the computed `ŷ` over `P·b` (`lpre_rest` reads
  `cᵢ`, `lpre_get` the earlier `ŷₖ`), with the inner sum `c_ydot` (`c_ydot_succ`, `c_y_eq`); the
  back loop keeps `x` as `lsuf` of the computed `x̂` over `ŷ` (`lsuf_rest` reads `ŷᵢ`, `lsuf_get`
  the later `x̂ₖ`), with the inner sum `c_xdot` (`c_xdot_succ`, `c_x_eq`). `c_pb` names `P·b` so
  that `entailer!`, which substitutes `n := Zlength pl` (VST-008), leaves it intact. Proof:
  `body_diana_lu_solve` in `verification/rocq/theory/VST/LUSolve.v`.

## Model correspondence

- **Layer A** (`verification/lean/Diana/Real/LUSolve.lean`,
  `verification/rocq/theory/Real/LUSolve.v`): `pperm`, `ipperm`, `solution` and `pivots` have the
  same definitions in both provers, over `fwd`, `bwd`, `lo` and `up` of `Diana.Real.Substitution`
  and `Diana.Real.LU`; sums are over `Finset.range` and `Finset.Ico` in Lean and the `sum` of
  `Diana.Real.Cholesky` in Rocq.
- **Layer B** (`verification/rocq/theory/Float/LUSolve.v`): `funit` and `fforward` (no division)
  and `fsolution` (`Substitution.fbwd` on `fun k i => F i k`) with Cholesky's `fsub` and
  `Diana.Float.Sum`'s `fmul` and `fdiv`, in `mode_NE` and parameterised by the NaN-payload
  functions; `fpivots` are the pivot rows of `Diana.Float.LU.fstate`.
- **Layer C, VST** (`verification/rocq/theory/VST/LUSolve.v` against
  `verification/clight/lu_solve_aarch64_macos.v`, CompCert target AArch64 macOS): `c_y` and
  `c_x` are `fforward` and `fsolution` instantiated with CompCert's `Float.binop_nan`, so the
  operations are `Float.sub`, `Float.mul` and `Float.div` by conversion, at
  `F i k = Znth (i + k·n) ll` (`c_L` of `VST/Substitution.v`), `p k = Znth k pl` and
  `b i = Znth i bl`; `diag_nonzero` and `vec_finite` are those of `VST/Substitution.v`.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| LU-SOLVE-A1 | proved | proved | – |
| LU-SOLVE-A2 | proved | proved | – |
| LU-SOLVE-A3 | proved | proved | – |
| LU-SOLVE-B1 | – | proved | – |
| LU-SOLVE-B2 | – | proved | – |
| LU-SOLVE-B3 | – | proved | – |
| LU-SOLVE-B4 | – | proved | – |
| LU-SOLVE-C1 | – | – | 180/180 goals (Frama-C 32.1, Alt-Ergo 2.6.4) |
| LU-SOLVE-C2 | – | proved | – |
| LU-SOLVE-C3 | – | proved | – |
