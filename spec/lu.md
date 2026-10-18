---
method: lu
kernel: src/lu.c
model: >
  lu A n : ℝ^{n×n}, the packed factorization P·A = L·U with partial pivoting, computed in place
  on a working matrix that starts as A: step k = 0, …, n − 1 scans column k from row k down and
  takes as pivot row p the first row of largest magnitude |B[i, k]|, i ≥ k; interchanges rows k
  and p across every column; replaces each B[i, k], i > k, by the multiplier B[i, k] / B[k, k];
  and replaces each B[i, j], i > k, j > k, by B[i, j] − (B[i, k] / B[k, k])·B[k, j]. The result
  holds L strictly below the diagonal (its unit diagonal not stored) and U on and above it; row i
  of P·A is row prow A n i of A. The model is one definition over any number type (Diana.Real.LU
  ops): the reals for layer A, and for layer B binary64 with each subtraction, product and
  quotient rounded to nearest-even (no fused multiply-add), the magnitude v < 0 ? −v : v and the
  comparison |v| > m of the C; the C stores A, L and U column-major, a[i + j·n] = A[i, j].
hypothesis:
  - "H1: A is a real n×n matrix given by its entries A i j; every entry is read. A2 and A6 take the magnitude tested at every step k < n nonzero, A5 that magnitude nonzero before step k and zero at step k; A1 takes the unpivoted pivots nonzero; A3 and A4 take nothing"
  - "H2 (float layers): the entries are arbitrary binary64 values; the B theorems take the conditions of the C's DIANA_OK (fok): every entry of a finite, and at each step k < n a pivot magnitude that is not 0.0 and updates B[i, j], i, j > k, that are all finite; B3 and B4 take (number of terms)·u < 1, u = 2⁻⁵³"
theorem:
  - id: LU-A1
    layer: A
    informal: "correctness of the unpivoted steps (Doolittle): if the pivots U[k, k], k < n, of the elimination without interchanges are nonzero, then Σ_{t<n} L[i, t]·U[t, j] = B[i, j] for i, j < n, L unit lower triangular and U upper triangular"
    lean: Diana.Real.LU.product
    rocq: Diana.Real.LU.product
  - id: LU-A2
    layer: A
    informal: "correctness with partial pivoting: if the pivot magnitude of every step k < n is nonzero, then Σ_{t<n} L[i, t]·U[t, j] = A[prow i, j] for i, j < n, that is P·A = L·U; the pivoted elimination is the unpivoted one of P·A (state_nstate)"
    lean: Diana.Real.LU.pivot_product
    rocq: Diana.Real.LU.pivot_product
  - id: LU-A3
    layer: A
    informal: "the interchanges form a permutation, for any number type, so also for the binary64 model of the C: the pivot row of step k < n is in [k, n), and i ↦ prow i maps [0, n) onto [0, n) one to one"
    lean: Diana.Real.LU.permutation
    rocq: Diana.Real.LU.permutation
  - id: LU-A4
    layer: A
    informal: "partial pivoting bounds the multipliers: |L[i, j]| ≤ 1 for j < i < n"
    lean: Diana.Real.LU.multiplier_bound
    rocq: Diana.Real.LU.multiplier_bound
  - id: LU-A5
    layer: A
    informal: "a zero pivot means a singular matrix: if the pivot magnitudes of the steps before k < n are nonzero and that of step k is zero, then A·x = 0 for some x with x_k = 1 and x_j = 0 for j > k"
    lean: Diana.Real.LU.singular
    rocq: Diana.Real.LU.singular
  - id: LU-A6
    layer: A
    informal: "nonzero pivots mean a nonsingular matrix: if the pivot magnitude of every step k < n is nonzero, then A·x = 0 on the indices below n only for x = 0 there; with A5, exact partial pivoting succeeds exactly on the nonsingular matrices"
    lean: Diana.Real.LU.nonsingular
    rocq: Diana.Real.LU.nonsingular
  - id: LU-B1
    layer: B
    informal: >
      finiteness: under the C's DIANA_OK conditions every entry of the binary64 factor is finite.
      The C checks only the updates: a pivot row holds earlier updates or entries of a, and a
      multiplier is a quotient of magnitude at most 1 by a finite nonzero pivot.
    rocq: Diana.Float.LU.finite_result
  - id: LU-B2
    layer: B
    informal: "partial pivoting bounds the binary64 multipliers: under the C's DIANA_OK conditions |L̂[i, j]| ≤ 1 for j < i < n (round-to-nearest is monotone and 1 is a binary64 number)"
    rocq: Diana.Float.LU.multiplier_bound
  - id: LU-B3
    layer: B
    informal: >
      backward error on and above the diagonal: under the C's DIANA_OK conditions, for i ≤ j < n
      and i·u < 1, with B = P̂·A the rows of a interchanged as the C did,
      |B[i, j] − Σ_{t<i} L̂[i, t]·Û[t, j] − Û[i, j]| ≤ γᵢ·(Σ_{t<i} |L̂[i, t]·Û[t, j]| + |Û[i, j]|) + (1 + γᵢ)·i·η,
      γₖ = k·u/(1 − k·u), η = 2⁻¹⁰⁷⁵ (underflow in the products).
    rocq: Diana.Float.LU.upper_error
  - id: LU-B4
    layer: B
    informal: >
      backward error below the diagonal: under the same conditions, for j < i < n and
      (j + 1)·u < 1, |B[i, j] − Σ_{t<j} L̂[i, t]·Û[t, j] − Û[j, j]·L̂[i, j]|
      ≤ γⱼ₊₁·(Σ_{t<j} |L̂[i, t]·Û[t, j]| + |Û[j, j]·L̂[i, j]|) + (1 + γⱼ₊₁)·(j + |Û[j, j]|)·η.
      With B3 this is Higham's P̂·A + ΔA = L̂·Û, |ΔA| ≤ γₙ·|L̂|·|Û| (Theorem 9.3), with the
      underflow terms.
    rocq: Diana.Float.LU.lower_error
  - id: LU-C1
    layer: C
    informal: >
      ACSL contract in src/lu.c, Frama-C WP float model with RTE: memory safety (only
      a[0 .. n·n−1] is read, only lu[0 .. n·n−1] and piv[0 .. n−1] are written, the three
      separate), no UB, no wrap of the size_t indices i + j·n, termination of all eight loops, a
      status in {DIANA_OK, DIANA_ERR_ARG, DIANA_ERR_SINGULAR}, any status other than
      DIANA_ERR_ARG only for non-NULL pointers with n ≥ 1 and n·n ≤ SIZE_MAX, lu and piv
      untouched when an entry of a is not finite, and k ≤ piv[k] < n for every k on DIANA_OK.
    acsl: src/lu.c
  - id: LU-C2
    layer: C
    informal: >
      diana_lu computes the binary64 model (VST, AArch64 macOS Clight AST): for a pointing to
      n·n readable doubles, lu to n·n writable doubles and piv to n writable size_t, held by
      separate data_at, with n ≥ 1 and n·n ≤ 2⁶⁴ − 1, it returns DIANA_OK exactly when the
      DIANA_OK conditions of the B theorems hold, and then lu holds the model factor column-major
      and piv[k] the model pivot row of step k; DIANA_ERR_ARG with lu and piv unchanged when an
      entry of a is not finite; DIANA_ERR_SINGULAR when the first failing step has a pivot
      magnitude equal to 0.0; DIANA_ERR_ARG when it has a nonzero pivot and an update that is
      not finite. lu and piv have unspecified contents on the last two. The NULL, n = 0 and
      overflowing-n paths are C1.
    rocq: Diana.VST.LU.body_diana_lu
  - id: LU-C3
    layer: C
    informal: >
      the copy of diana_fp_finite in the Clight AST of lu implements its IEEE semantics, as
      CHOLESKY-C4 (VST, AArch64 macOS Clight AST).
    rocq: Diana.VST.LU.body_diana_fp_finite
---
# lu

LU factorization with partial pivoting `P·A = L·U` of a square `n×n` matrix. The kernel
`diana_lu(a, n, lu, piv)` reads `A` from `a`, stored column-major in one buffer of `n·n` doubles
(`a[i + j·n] = A[i, j]`), and writes the packed factor to the separate buffer `lu` in the same
layout: `L` strictly below the diagonal, its unit diagonal not stored, and `U` on and above it.
`piv[k]` is the row interchanged with row `k` at step `k`, as in LAPACK's `getrf` with indices
from 0.

## Operation order

The binary64 model, and every layer that follows it, is the order of the C:

1. Reject NULL pointers, `n = 0` and an `n` whose `n·n` does not fit in `size_t`; check every
   entry of `a` with `diana_fp_finite` in linear order, before writing anything. Each failure is
   `DIANA_ERR_ARG` with `lu` and `piv` untouched. Then copy `a` to `lu`.
2. For `k = 0, …, n − 1`, on the working matrix in `lu`:
   - search: `p = k`, `m = 0.0`; for `i = k, …, n − 1`, `v = lu[i + k·n]`, `v = −v` if `v < 0`,
     and `p = i`, `m = v` if `v > m`. So `p` is the first row of largest magnitude, and `m` that
     magnitude;
   - if `m == 0.0`, return `DIANA_ERR_SINGULAR`; else `piv[k] = p`;
   - interchange rows `k` and `p` in every column `j = 0, …, n − 1` (a row with itself when
     `p = k`);
   - `d = lu[k + k·n]`, and `lu[i + k·n] = lu[i + k·n] / d` for `i > k`, a division rather than a
     product with `1/d`;
   - for each column `j > k` and row `i > k`, `t = lu[i + j·n] − lu[i + k·n]·lu[k + j·n]`, the
     product rounded first; a non-finite `t` returns `DIANA_ERR_ARG`, else `lu[i + j·n] = t`.

Every entry of `U` is thus `A[i, j]` of the interchanged matrix minus the rounded products
`L[i, t]·U[t, j]`, `t = 0, …, i − 1`, subtracted in that order, and every entry of `L` that
difference for `t < j` divided by `U[j, j]`: the order of the unpivoted (Doolittle) recurrence on
`P·A`. On `DIANA_OK` every entry is finite (B1), since the updates are checked, the pivot row holds
earlier updates, and each multiplier has magnitude at most 1 (B2).

## Proof sketch

- **Generic model** (`verification/rocq/theory/Real/LU.v`, Lean the same): `search`, `swap`,
  `elim`, `state` (pivoted) and `nstate` (unpivoted) take the operations as a record `ops`. The
  structural lemmas hold for any operations: `elim_swap`, step `k` commutes with interchanging two
  rows below `k`, since it treats each row below `k` on its own with row `k` as pivot row; by
  induction `nstate_swap` and then `state_nstate`, the pivoted working matrix after `k` steps is
  the unpivoted one of `P_k·A`. `nstate_row`, `nstate_col` and `nstate_dot` give the Doolittle
  recurrence entry by entry, in the C's order of subtractions.
- **A1**: `product` from `nstate_dot`, `nstate_mult` and `rdot_sum`, case `i ≤ j` and `i > j`.
  **A2**: A1 for `P·A`; the pivot `U[k, k]` is the entry the search chose (`state_diag`), whose
  magnitude is the tested one (`rtop_spec`). **A3**: `pivot_range`, `perm_inj`, and the explicit
  inverse `iperm` (`perm_iperm`), since each step's transposition is an involution.
- **A4**: the multiplier of row `r` at step `j` is `B[τ(r), j] / B[p, j]` with `|B[τ(r), j]| ≤
  |B[p, j]|` by the search, and later steps only interchange rows below `j` and leave column `j`.
- **A5**: with `B = P_k·A`, column `k` of `B` is `L_k·u` with `u = U[0..k−1, k]` because the
  Schur column below `k` is zero, and the columns before `k` are `L_k·U_k` (`column_product`);
  back substitution (`Substitution.back_solve`) gives `U_k·y = u`, so `x = (−y, 1, 0, …)` solves
  `B·x = 0`, and `A·x = 0` through `iperm`. **A6**: from A2, `L·(U·x) = 0` gives `U·x = 0` by
  `forward_unique` (unit diagonal) and then `x = 0` by `back_unique`.
- **B1, B2**: on finite entries the binary64 search is the real search on their values
  (`fsearch_real`, from `Bcompare_correct`), so the pivot has the largest magnitude; a quotient of
  magnitude at most 1 rounds to at most 1 (`fdiv_bounded`); the trailing block is finite by the
  `DIANA_OK` conditions (`trailing_finite`) and column `j` below the diagonal by induction over the
  later interchanges (`multiplier_ok`).
- **B3, B4**: `state_nstate` instantiated with binary64 makes the factor the unpivoted one of
  `P̂·A` bit for bit (`flu_dot`, `flu_upper`, `flu_lower`); an entry of `U` is
  `Substitution.fdotv` of its row, whose error is Cholesky's `dot_error` (`dotv_error`), and an
  entry of `L` that value divided by `U[j, j]`, whose error is `Substitution.row_error`.
- **C1**: the `/*@ ... */` annotations in `src/lu.c`. The index bounds use the lemma `column_end`
  and an assertion `0 <= n * (n - 1 - k)` (or `j`) at the head of each step and column loop, as
  in CHOLESKY-C1 (WP-011). The magnitude is computed in line (`v < 0.0 ? −v`) rather than with
  `diana_fp_abs`, whose `\is_finite` precondition would need WP to know that every multiplier
  is finite, a float fact it cannot prove; WP proves no finiteness, which is B1.
- **C2**: the validation loop carries "every entry checked so far is finite", the copy loop
  `lpre` of `VST/Matrix.v`; then each step keeps `lu` as `mlist n M`, the column-major list of a
  matrix function `M`, with `M` a partial state of the step: the search state, `pswap` (rows
  interchanged in the columns before `j`), `pmult` (multipliers of the rows before `i`) and
  `pcell` (the cells before `(i, j)` eliminated), each store being `upd_mlist` followed by a
  pointwise lemma (`pswap_step`, `pmult_step`, `pcell_step`) through `mlist_ext`. `piv` is a
  prefix of the model pivots (`vpre`). `pfin` records that the cells updated so far are finite,
  which with the zero test gives `step_ok`. Proof: `body_diana_lu` in
  `verification/rocq/theory/VST/LU.v`.

## Model correspondence

- **Layer A** (`verification/lean/Diana/Real/LU.lean`, `verification/rocq/theory/Real/LU.v`):
  the matrix is a function `ℕ → ℕ → T`; `search`, `pivot`, `top`, `swap`, `elim`, `state`,
  `nstate`, `tau`, `perm`, `iperm`, `permute` and `dot` have the same definitions in both
  provers over a record of operations, instantiated at the reals as `rops` (exact arithmetic,
  `|x|`, `<`); sums are over `Finset.range` in Lean and the `sum` of `Diana.Real.Cholesky` in
  Rocq. Lean states the structural lemmas as equalities of functions, Rocq pointwise.
- **Layer B** (`verification/rocq/theory/Float/LU.v`): `fops` instantiates the same model with
  Cholesky's `fsub` (`Bminus`), `Diana.Float.Sum`'s `fmul` and `fdiv`, the magnitude
  `fmag x = if x < 0 then Bopp x else x` and the comparison `fgtb` (`Bcompare = Some Gt`), all
  parameterised by the NaN-payload functions; `fok` is the C's `DIANA_OK` condition, with the
  pivot test `feqb (ftop …) 0 = false` (`Bcompare = Some Eq`).
- **Layer C, VST** (`verification/rocq/theory/VST/LU.v` against
  `verification/clight/lu_aarch64_macos.v`, CompCert target AArch64 macOS): `cops` is `fops`
  instantiated with CompCert's `Float.binop_nan` and `Float.neg_nan`, so `fsub`, `fmul`, `fdiv`,
  `fmag` and `fgtb` are `Float.sub`, `Float.mul`, `Float.div`, `Float.cmp Clt`/`Float.neg` and
  `Float.cmp Cgt` by conversion, at `A i j = Znth (i + j·n) al`; `c_step_ok`, `c_ok`,
  `c_zero_pivot` and `c_overflow` are the C's exits.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| LU-A1 | proved | proved | – |
| LU-A2 | proved | proved | – |
| LU-A3 | proved | proved | – |
| LU-A4 | proved | proved | – |
| LU-A5 | proved | proved | – |
| LU-A6 | proved | proved | – |
| LU-B1 | – | proved | – |
| LU-B2 | – | proved | – |
| LU-B3 | – | proved | – |
| LU-B4 | – | proved | – |
| LU-C1 | – | – | 157/157 goals (Frama-C 32.1, Alt-Ergo 2.6.4) |
| LU-C2 | – | proved | – |
| LU-C3 | – | proved | – |
