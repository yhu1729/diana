---
method: cholesky
kernel: [src/fp_sqrt.c, src/cholesky.c]
model: >
  chol A : ℝ^{n×n}, the lower-triangular L with A = L·Lᵀ, column by column from the entries
  A[i, j], i ≥ j: for j = 0, …, n − 1, the pivot pⱼ = A[j, j] − Σ_{k<j} L[j, k]², L[j, j] = √pⱼ,
  L[i, j] = (A[i, j] − Σ_{k<j} L[i, k]·L[j, k]) / L[j, j] for i > j, and L[i, j] = 0 for i < j.
  The binary64 model evaluates each sum as s = A[i, j], then s = fl(s − fl(L[i, k]·L[j, k])) for
  k = 0, …, j − 1 in that order, L[j, j] = fl(√pⱼ) and L[i, j] = fl(s / L[j, j]), each operation
  rounded to nearest-even (no fused multiply-add); the C stores A and L column-major,
  a[i + j·n] = A[i, j].
hypothesis:
  - "H1: A is a real n×n matrix given by its entries A i j; only those with j ≤ i are read. A2 and A3 take A symmetric on the indices below n and positive definite as xᵀAx > 0 for every x with some xᵢ ≠ 0, i < n"
  - "H2 (float layers): the entries are arbitrary binary64 values; B2 and B3 take the conditions of the C's DIANA_OK, every entry on or below the diagonal finite and every pivot positive (IEEE comparison s > 0), and B3 takes (j + 2)·u < 1 for column j, u = 2⁻⁵³"
theorem:
  - id: CHOLESKY-A1
    layer: A
    informal: "correctness: if the pivots p₀, …, pₙ₋₁ are positive, then Σ_{k<n} L[i, k]·L[j, k] = A[i, j] for j ≤ i < n, that is L·Lᵀ = A on the lower triangle"
    lean: Diana.Real.Cholesky.product
    rocq: Diana.Real.Cholesky.product
  - id: CHOLESKY-A2
    layer: A
    informal: "existence: under H1, if A is symmetric positive definite then every pivot pⱼ, j < n, is positive, so the factorization succeeds in exact arithmetic"
    lean: Diana.Real.Cholesky.pivot_pos
    rocq: Diana.Real.Cholesky.pivot_pos
  - id: CHOLESKY-A3
    layer: A
    informal: "converse: a symmetric A whose pivots p₀, …, pₙ₋₁ are all positive is positive definite; with A2, exact arithmetic succeeds exactly on symmetric positive definite matrices"
    lean: Diana.Real.Cholesky.pos_def
    rocq: Diana.Real.Cholesky.pos_def
  - id: CHOLESKY-B1
    layer: B
    informal: >
      the contract that WP assumes for diana_fp_sqrt (src/fp_sqrt.h, the SKIP entry): for a
      binary64 x > 0 (IEEE, so not NaN), a finite x gives a finite, positive result equal to the
      correctly rounded √x, and +∞ gives +∞ (Flocq Bsqrt in mode_NE, parameterised by the
      NaN-payload function so that it instantiates to CompCert's Float.sqrt).
    rocq: Diana.Float.Cholesky.sqrt_contract
  - id: CHOLESKY-B2
    layer: B
    informal: >
      finiteness: with every entry on or below the diagonal finite and every pivot positive (the
      C's DIANA_OK), every entry of the binary64 factor is finite. A pivot is never +∞, since only
      squares are subtracted from a finite A[j, j], and a non-finite L[i, j], j < i, would make
      the pivot of column i −∞ or NaN; this is why the kernel checks only the pivots.
    rocq: Diana.Float.Cholesky.finite_result
  - id: CHOLESKY-B3
    layer: B
    informal: >
      backward error: under the hypotheses of B2 and (j + 2)·u < 1, each entry j ≤ i < n of the
      binary64 factor L̂ satisfies
      |A[i, j] − Σ_{k≤j} L̂[i, k]·L̂[j, k]| ≤ γⱼ₊₂·Σ_{k≤j} |L̂[i, k]·L̂[j, k]| + (1 + γⱼ₊₂)·(j + |L̂[j, j]|)·η,
      γₖ = k·u/(1 − k·u), η = 2⁻¹⁰⁷⁵ (underflow in the products and the division): Higham's
      componentwise bound L̂·L̂ᵀ = A + ΔA, |ΔA| ≤ γₙ₊₁·|L̂|·|L̂ᵀ|, with the underflow terms.
    rocq: Diana.Float.Cholesky.backward_error
  - id: CHOLESKY-C1
    layer: C
    informal: >
      ACSL contract in src/cholesky.c, Frama-C WP float model with RTE: memory safety (only
      a[0 .. n·n−1] is read, only l[0 .. n·n−1] is written, l separate from a), no UB, no wrap of
      the size_t index i + j·n, termination of all six loops, a status in {DIANA_OK,
      DIANA_ERR_ARG, DIANA_ERR_SINGULAR}, any status other than DIANA_ERR_ARG only for non-NULL
      pointers with n ≥ 1 and n·n ≤ SIZE_MAX, and l untouched on DIANA_ERR_ARG. The only
      assumed contract is diana_fp_sqrt (src/fp_sqrt.h, SKIP), discharged by CHOLESKY-B1.
    acsl: src/cholesky.c
  - id: CHOLESKY-C2
    layer: C
    informal: >
      diana_fp_sqrt returns Float.sqrt x (VST, AArch64 macOS Clight AST), assuming for the call
      to __builtin_sqrt the funspec Float.sqrt, the semantics CompCert gives the builtin (VST has
      no rule for a builtin call; doc/verification/trust.md).
    rocq: Diana.VST.FpSqrt.body_diana_fp_sqrt
  - id: CHOLESKY-C3
    layer: C
    informal: >
      diana_cholesky computes the binary64 model (VST, AArch64 macOS Clight AST): for a pointing
      to n·n readable doubles and l to n·n writable doubles, the two disjoint, with n ≥ 1 and
      n·n ≤ 2⁶⁴ − 1, it returns DIANA_OK exactly when every entry on or below the diagonal is
      finite and every pivot test s > 0 passes, and then l holds the model factor column-major
      with the strict upper triangle +0; it returns DIANA_ERR_ARG exactly when an entry on or
      below the diagonal is not finite, leaving l unchanged; otherwise DIANA_ERR_SINGULAR, with
      l of unspecified contents. The NULL, n = 0 and overflowing-n paths are CHOLESKY-C1.
    rocq: Diana.VST.Cholesky.body_diana_cholesky
  - id: CHOLESKY-C4
    layer: C
    informal: >
      the copy of diana_fp_finite in the Clight AST of cholesky implements its IEEE semantics, as
      BISECTION-C5 for the copy in bisection_init (VST, AArch64 macOS Clight AST).
    rocq: Diana.VST.Cholesky.body_diana_fp_finite
---
# cholesky

Cholesky factorization `A = L·Lᵀ` of a symmetric positive definite `n×n` matrix. The kernel
`diana_cholesky(a, n, l)` reads `A` from `a`, stored column-major in one buffer of `n·n` doubles
(`a[i + j·n] = A[i, j]`), uses only the entries on or below the diagonal, and writes the
lower-triangular factor to the separate buffer `l` in the same layout, with the strict upper
triangle `+0`. The square root comes from the helper `diana_fp_sqrt` (`src/fp_sqrt.c`), the one
function in Diana that calls a compiler builtin.

## Operation order

The binary64 model, and every layer that follows it, is the order of the C:

1. Reject NULL pointers, `n = 0` and an `n` whose `n·n` does not fit in `size_t`; then check every
   entry on or below the diagonal with `diana_fp_finite`, column by column, before writing
   anything. Each failure is `DIANA_ERR_ARG` with `l` untouched.
2. For `j = 0, …, n − 1`: write `+0` to `l[i + j·n]` for `i < j`; set `s = a[j + j·n]` and
   `s = s − l[j + k·n]·l[j + k·n]` for `k = 0, …, j − 1`, each product rounded before the
   subtraction; if `!(s > 0)`, return `DIANA_ERR_SINGULAR`; otherwise `d = diana_fp_sqrt(s)` and
   `l[j + j·n] = d`; then for each `i > j`, `s = a[i + j·n]`, the same subtractions with
   `l[i + k·n]·l[j + k·n]`, and `l[i + j·n] = s / d`, a correctly rounded division.

Every write goes to the next linear index, so `l` always holds a prefix of the model factor
followed by the caller's contents. A NaN pivot fails the test as a negative one does, and no
other check is needed: a pivot cannot overflow to `+∞` and a non-finite entry below the diagonal
makes a later pivot `−∞` or NaN (B2), so on `DIANA_OK` every entry is finite.

## Proof sketch

- **A1**: `entry` closes the recurrence entry by entry: for `j < i`,
  `Σ_{k<j} L[i,k]L[j,k] + L[i,j]·L[j,j] = A[i,j]` once `√pⱼ ≠ 0`, and for `i = j`,
  `Σ_{k<j} L[j,k]² + (√pⱼ)² = A[j,j]`; `L[j,k] = 0` for `k > j` extends the sum to `k < n`. The
  factor is defined column by column (`factor` builds columns `0, …, m − 1`, `chol A i k` reads
  column `k` of `factor A (k + 1)`), and `chol_eq` states the recurrence.
- **A2**: strong induction on `j`. With the pivots before `j` positive, back substitution
  (`back`, by induction from row `j − 1` down) gives `x` with `xⱼ = 1`, `xᵢ = 0` for `i > j` and
  `Σ_{i≤j} L[i,m]·xᵢ = 0` for `m < j`; `quad` computes `xᵀAx = Σ_{m<j} (Σ_{i≤j} L[i,m]xᵢ)² + pⱼxⱼ²`
  from A1 and the symmetry of `A`, so `xᵀAx = pⱼ`, positive by definiteness.
- **A3**: with all pivots positive, A1 and symmetry give `xᵀAx = Σ_{m<n} (Σᵢ L[i,m]xᵢ)²`; for the
  last index `t` with `x_t ≠ 0`, the term `m = t` is `(L[t,t]·x_t)² > 0`.
- **B1**: `Bsqrt_correct`; positivity because `√x ≥ √2⁻¹⁰⁷⁴ = 2⁻⁵³⁷`, a binary64 number, so the
  rounded root is at least `2⁻⁵³⁷`. Proof: `sqrt_contract` in
  `verification/rocq/theory/Float/Cholesky.v`.
- **B2**: a square `fl(x·x)` is NaN or has a clear sign bit (`fmul_sq_nonneg`, from the sign
  rule of `Bmult_correct`), so `fl(s − p)` is `+∞` only if `s` is (`fsub_not_pinf`: in the
  overflow branch of `Bminus_correct` the sign is that of `s`, which is negative); once `−∞` or
  NaN, `s` stays so (`fsub_bad`), and a non-finite `L[i,k]` makes the square `+∞` or NaN
  (`fsub_make_bad`). A positive pivot is therefore finite, and its root finite (B1). Proof:
  `finite_result`.
- **B3**: `dot_error` by induction over the subtractions: with `fl(s − q) = (s − q)(1 + ε)`
  (`add_error`, no absolute term) and `fl(L·L) = t(1 + δ) + e` (`round_error`), there is a
  factor `F`, a product of `k` terms `(1 + ε)^{±1}` with `|F − 1| ≤ γₖ` (`factor_mul`,
  `factor_div`, Higham's Lemma 3.1), such that
  `|A[i,j] − Σ_{k'<k} t_{k'} − ŝₖ·F| ≤ γₖ·Σ|t_{k'}| + (1 + γₖ)·k·η`. The last step uses
  `ŝ = L̂[j,j]²/(1 + δ)²` on the diagonal (`sqrt_error`: the root of a positive binary64 is
  normal, so relative error only) and `ŝ = (L̂[i,j] − e)·L̂[j,j]/(1 + δ)` below it (`div_error`).
  Proof: `backward_error`.
- **C1**: the `/*@ ... */` annotations in `src/cholesky.c`. The runtime check `n > SIZE_MAX / n`
  gives `n·n ≤ SIZE_MAX` (an asserted fact Alt-Ergo proves from the division). The nonlinear
  bound `i + j·n < n·n` comes from the lemma `column_end`,
  `0 ≤ n·(n − 1 − j)` for `0 ≤ j < n`, which Alt-Ergo proves in that factored form, and an
  `assert 0 <= n * (n - 1 - j)` (and with `k`) at the head of each column and inner loop: the
  assertion's product matches the lemma's trigger, and once it is a hypothesis every index bound
  and the `size_t` no-wrap goals are linear in the monomials `n·n` and `j·n`. The sqrt
  precondition is the IEEE comparison `\gt_double(x, 0.0)`, which the C test `!(s > 0.0)`
  establishes directly; WP cannot prove `\is_finite(s)` (B2 is a float fact), so the contract
  does not ask for it. That every entry is finite on `DIANA_OK` is left to VST.
- **C2**: `forward_call` on the assumed builtin funspec. Proof: `body_diana_fp_sqrt` in
  `verification/rocq/theory/VST/FpSqrt.v`.
- **C3**: the validation loops carry "every entry checked so far is finite"; a failing
  `diana_fp_finite` returns with `~ lower_finite`. The factorization keeps `l` as
  `lpre L ol (n·n) p = map Vfloat (sublist 0 p L) ++ sublist p (n·n) ol` with `L = c_list al n`
  the model factor in column-major order and `p` the next linear index: `j·n` per column,
  `j·n + i` in the zeroing and below-diagonal loops. Each store is `lpre_step` and each load
  below `p` is `lpre_get` (stated for any `Inhabitant val`, since VST's loads carry their own),
  and `Znth_c_list` with `c_dot_succ`, `c_l_upper`, `c_l_diag` and `c_l_lower` name the stored
  values. VST reduces the `Int64` index `i + j·n` itself once the bounds are in context
  (`nia`). The inner `for` loop that ends each column body is wrapped as `loop; skip`
  (`semax_seq_skip`) so that `forward_for` with a break assertion applies. Proof:
  `body_diana_cholesky` in `verification/rocq/theory/VST/Cholesky.v`.

## Model correspondence

- **Layer A** (`verification/lean/Diana/Real/Cholesky.lean`,
  `verification/rocq/theory/Real/Cholesky.v`): the matrix is a function `ℕ → ℕ → ℝ`, sums are
  over `Finset.range` in Lean and the `Fixpoint sum` of the Rocq file, and `pivot`, `column`,
  `factor`, `chol` and `piv` have the same definitions in both provers.
- **Layer B** (`verification/rocq/theory/Float/Cholesky.v`): `fdot`, `fpivot`, `fcolumn`,
  `ffactor`, `fchol` and `fpiv` mirror layer A in binary64 with `fsub` (`Bminus`), `fmul`,
  `fdiv` (`Diana.Float.Sum`) and `fsqrt` (`Bsqrt`), all in `mode_NE` and parameterised by the
  NaN-payload functions; `positive x` is `Bcompare x (+0) = Some Gt`, the C test `s > 0.0`.
- **Layer C, VST** (`verification/rocq/theory/VST/Cholesky.v` against
  `verification/clight/cholesky_aarch64_macos.v`, `verification/rocq/theory/VST/FpSqrt.v` against
  `verification/clight/fp_sqrt_aarch64_macos.v`, CompCert target AArch64 macOS): `c_l al n i j`
  is `fchol` instantiated with CompCert's `Float.binop_nan` and `Float.unop_nan`, so that
  `fsub`, `fmul`, `fdiv` and `fsqrt` are `Float.sub`, `Float.mul`, `Float.div` and `Float.sqrt`
  by conversion, at `A i j = Znth (i + j·n) al`; `pivots_ok` is `Float.cmp Cgt (c_piv al n j)
  Float.zero = true` for `j < n`, which is `positive` of layer B.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| CHOLESKY-A1 | proved | proved | – |
| CHOLESKY-A2 | proved | proved | – |
| CHOLESKY-A3 | proved | proved | – |
| CHOLESKY-B1 | – | proved | – |
| CHOLESKY-B2 | – | proved | – |
| CHOLESKY-B3 | – | proved | – |
| CHOLESKY-C1 | – | – | 108/108 goals (Frama-C 32.1, Alt-Ergo 2.6.4), assumed contract of diana_fp_sqrt (CHOLESKY-B1) |
| CHOLESKY-C2 | – | proved, assuming the funspec of `__builtin_sqrt` | – |
| CHOLESKY-C3 | – | proved | – |
| CHOLESKY-C4 | – | proved | – |
