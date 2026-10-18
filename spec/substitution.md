---
method: substitution
kernel: [src/forward_substitution.c, src/transpose_substitution.c]
model: >
  fwd L b : ℝ^n, the solution of L·x = b for a lower-triangular L, row by row:
  xᵢ = (bᵢ − Σ_{k<i} L[i, k]·x_k) / L[i, i] for i = 0, …, n − 1, reading only L[i, k] with k ≤ i.
  bwd L b n, the solution of Lᵀ·x = b, is fwd on the mirrored system L′[p, q] = L[n−1−q, n−1−p],
  b′_p = b_{n−1−p} at p = n − 1 − i, so xᵢ = (bᵢ − Σ_{k>i} L[k, i]·x_k) / L[i, i] for
  i = n − 1, …, 0. The binary64 model evaluates each row as s = bᵢ, then s = fl(s − fl(L·x_k)) for
  k = 0, …, i − 1 (forward) or k = n − 1 down to i + 1 (back, the order the unknowns were
  computed), and xᵢ = fl(s / L[i, i]), each operation rounded to nearest-even (no fused
  multiply-add); the C stores L column-major, l[i + k·n] = L[i, k].
hypothesis:
  - "H1: L is a real n×n matrix given by its entries L i k; only those with k ≤ i are read, and b is a real vector. A1, A4 take L i i ≠ 0 in the row; A2, A3, A5, A6 take it for every i < n; A7 takes A symmetric with positive Cholesky pivots, as CHOLESKY-A1 and A3"
  - "H2 (float layers): the entries are arbitrary binary64 values; B1 and B3 take the computed xᵢ finite and L[i, i] a nonzero real, the conditions of the C's DIANA_OK for that row, and (number of terms)·u < 1, u = 2⁻⁵³; B2 and B4 take them for every i < n and n·u < 1"
theorem:
  - id: SUBSTITUTION-A1
    layer: A
    informal: "forward substitution solves each row: if L[i, i] ≠ 0 then Σ_{k≤i} L[i, k]·xₖ = bᵢ for x = fwd L b"
    lean: Diana.Real.Substitution.forward_solve
    rocq: Diana.Real.Substitution.forward_solve
  - id: SUBSTITUTION-A2
    layer: A
    informal: "uniqueness: if no diagonal entry below n is zero, any y with Σ_{k≤i} L[i, k]·yₖ = bᵢ for every i < n equals fwd L b on the indices below n"
    lean: Diana.Real.Substitution.forward_unique
    rocq: Diana.Real.Substitution.forward_unique
  - id: SUBSTITUTION-A3
    layer: A
    informal: >
      forward error from the residual: if no diagonal entry below n is zero and
      |bᵢ − Σ_{k≤i} L[i, k]·yₖ| ≤ ρᵢ for every i < n, then |(fwd L b)ᵢ − yᵢ| ≤ zᵢ with
      z = fwd M(L) ρ, M(L) the comparison matrix (|L[i, i]| on the diagonal, −|L[i, k]| off it),
      so zᵢ = (ρᵢ + Σ_{k<i} |L[i, k]|·z_k) / |L[i, i]|: |x − y| ≤ M(L)⁻¹·ρ.
    lean: Diana.Real.Substitution.forward_perturb
    rocq: Diana.Real.Substitution.forward_perturb
  - id: SUBSTITUTION-A4
    layer: A
    informal: "back substitution solves each row: for i < n with L[i, i] ≠ 0, Σ_{i≤k<n} L[k, i]·xₖ = bᵢ for x = bwd L b n, row i of Lᵀ·x = b"
    lean: Diana.Real.Substitution.back_solve
    rocq: Diana.Real.Substitution.back_solve
  - id: SUBSTITUTION-A5
    layer: A
    informal: "uniqueness: if no diagonal entry below n is zero, any y with Σ_{i≤k<n} L[k, i]·yₖ = bᵢ for every i < n equals bwd L b n on the indices below n"
    lean: Diana.Real.Substitution.back_unique
    rocq: Diana.Real.Substitution.back_unique
  - id: SUBSTITUTION-A6
    layer: A
    informal: >
      back-substitution forward error from the residual: if no diagonal entry below n is zero and
      |bᵢ − Σ_{i≤k<n} L[k, i]·yₖ| ≤ ρᵢ for every i < n, then |(bwd L b n)ᵢ − yᵢ| ≤ zᵢ with
      z = bwd M(L) ρ n, zᵢ = (ρᵢ + Σ_{k>i} |L[k, i]|·z_k) / |L[i, i]|.
    lean: Diana.Real.Substitution.back_perturb
    rocq: Diana.Real.Substitution.back_perturb
  - id: SUBSTITUTION-A7
    layer: A
    informal: >
      solving with the Cholesky factor: for A symmetric on the indices below n with every pivot
      positive (CHOLESKY-A2: A positive definite) and L = chol A, x = bwd L (fwd L b) n satisfies
      Σ_{k<n} A[i, k]·xₖ = bᵢ for every i < n, so L·y = b followed by Lᵀ·x = y solves A·x = b.
    lean: Diana.Real.Substitution.cholesky_solve
    rocq: Diana.Real.Substitution.cholesky_solve
  - id: SUBSTITUTION-B1
    layer: B
    informal: >
      backward error of forward substitution, row i: if the binary64 x̂ᵢ is finite, L[i, i] is a
      nonzero real and (i + 1)·u < 1, then
      |bᵢ − Σ_{k≤i} L[i, k]·x̂ₖ| ≤ γᵢ₊₁·Σ_{k≤i} |L[i, k]·x̂ₖ| + (1 + γᵢ₊₁)·(i + |L[i, i]|)·η,
      γₖ = k·u/(1 − k·u), η = 2⁻¹⁰⁷⁵ (underflow in the products and the division): x̂ solves
      (L + ΔL)·x̂ = b with |ΔL| ≤ γₙ·|L| (Higham, chapter 8), with the underflow terms.
    rocq: Diana.Float.Substitution.forward_backward_error
  - id: SUBSTITUTION-B2
    layer: B
    informal: >
      forward error of forward substitution: if every x̂ᵢ, i < n, is finite (the C's DIANA_OK),
      no L[i, i] is zero and n·u < 1, the exact solution x = fwd L b of the system on the binary64
      data satisfies |xᵢ − x̂ᵢ| ≤ zᵢ, z = fwd M(L) ρ with ρᵢ the bound of B1 (A3 applied to B1):
      |x − x̂| ≤ M(L)⁻¹·(γₙ·|L|·|x̂| + underflow).
    rocq: Diana.Float.Substitution.forward_forward_error
  - id: SUBSTITUTION-B3
    layer: B
    informal: >
      backward error of back substitution, row i < n: if the binary64 x̂ᵢ is finite, L[i, i] is a
      nonzero real and (n − i)·u < 1, then
      |bᵢ − Σ_{i≤k<n} L[k, i]·x̂ₖ| ≤ γₙ₋ᵢ·Σ_{i≤k<n} |L[k, i]·x̂ₖ|
      + (1 + γₙ₋ᵢ)·(n − 1 − i + |L[i, i]|)·η, B1 on the mirrored system.
    rocq: Diana.Float.Substitution.back_backward_error
  - id: SUBSTITUTION-B4
    layer: B
    informal: >
      forward error of back substitution: under the hypotheses of B2 for the back model, the
      exact solution x = bwd L b n satisfies |xᵢ − x̂ᵢ| ≤ zᵢ, z = bwd M(L) ρ n with ρᵢ the bound
      of B3 (A6 applied to B3).
    rocq: Diana.Float.Substitution.back_forward_error
  - id: SUBSTITUTION-C1
    layer: C
    informal: >
      ACSL contract in src/forward_substitution.c, Frama-C WP float model with RTE: memory safety
      (only l[0 .. n·n−1] and b[0 .. n−1] are read, only x[0 .. n−1] is written, x separate from
      l and b), no UB, no wrap of the size_t indices i + k·n, termination of all six loops, a
      status in {DIANA_OK, DIANA_ERR_ARG, DIANA_ERR_SINGULAR, DIANA_ERR_OVERFLOW}, any status
      other than DIANA_ERR_ARG only for non-NULL pointers with n ≥ 1 and n·n ≤ SIZE_MAX, x
      untouched on DIANA_ERR_SINGULAR, and every x[p] finite on DIANA_OK.
    acsl: src/forward_substitution.c
  - id: SUBSTITUTION-C2
    layer: C
    informal: >
      ACSL contract in src/transpose_substitution.c with the same clauses as C1, the solve loop
      running i = n − 1 down to 0 and k = n − 1 down to i + 1.
    acsl: src/transpose_substitution.c
  - id: SUBSTITUTION-C3
    layer: C
    informal: >
      diana_forward_substitution computes the binary64 model (VST, AArch64 macOS Clight AST):
      for l pointing to n·n readable doubles, b to n readable and x to n writable doubles, held
      by separate data_at, with n ≥ 1 and n·n ≤ 2⁶⁴ − 1, it returns DIANA_OK exactly when every
      entry of l on or below the diagonal and every b[i] is finite, no diagonal entry compares
      equal to 0.0 and every model entry x̂ᵢ is finite, and then x holds x̂; DIANA_ERR_ARG with x
      unchanged when an input entry is not finite; DIANA_ERR_SINGULAR with x unchanged when the
      inputs are finite and a diagonal entry is ±0; otherwise DIANA_ERR_OVERFLOW with x̂₀, …, x̂ᵢ₋₁
      written and the rest of x unchanged, x̂ᵢ the first entry that is not finite. The NULL, n = 0
      and overflowing-n paths are C1.
    rocq: Diana.VST.ForwardSubstitution.body_diana_forward_substitution
  - id: SUBSTITUTION-C4
    layer: C
    informal: >
      diana_transpose_substitution computes the binary64 model (VST, AArch64 macOS Clight AST), with
      the statuses of C3; on the overflow exit x̂ᵢ₊₁, …, x̂ₙ₋₁ are written, x̂ᵢ the first entry
      from the bottom that is not finite, and x[0 .. i] is unchanged. The NULL, n = 0 and
      overflowing-n paths are C2.
    rocq: Diana.VST.TransposeSubstitution.body_diana_transpose_substitution
  - id: SUBSTITUTION-C5
    layer: C
    informal: >
      the copy of diana_fp_finite in the Clight AST of forward_substitution implements its IEEE
      semantics, as CHOLESKY-C4 (VST, AArch64 macOS Clight AST).
    rocq: Diana.VST.ForwardSubstitution.body_diana_fp_finite
  - id: SUBSTITUTION-C6
    layer: C
    informal: >
      the copy of diana_fp_finite in the Clight AST of transpose_substitution implements its IEEE
      semantics (VST, AArch64 macOS Clight AST).
    rocq: Diana.VST.TransposeSubstitution.body_diana_fp_finite
---
# substitution

Forward and back substitution with a lower-triangular `n×n` matrix `L`: the kernel
`diana_forward_substitution(l, n, b, x)` solves `L·x = b`, and `diana_transpose_substitution(l, n, b,
x)` solves `Lᵀ·x = b`. Both read `L` from one buffer of `n·n` doubles stored column-major
(`l[i + k·n] = L[i, k]`), use only the entries on or below the diagonal, so the output of
`diana_cholesky` goes in as it is, and write `x` to a separate buffer of `n` doubles. Solving
`A·x = b` with `A = L·Lᵀ` is one call of each (A7).

## Operation order

The binary64 model, and every layer that follows it, is the order of the C:

1. Reject NULL pointers, `n = 0` and an `n` whose `n·n` does not fit in `size_t`; check every entry
   of `l` on or below the diagonal, column by column, then every `b[i]`, with `diana_fp_finite`;
   then every diagonal entry with `l[i + i·n] == 0.0`. A non-finite entry is `DIANA_ERR_ARG`, a
   zero (or `−0`) diagonal entry `DIANA_ERR_SINGULAR`; both leave `x` untouched, and a non-finite
   entry wins over a zero diagonal.
2. Forward, for `i = 0, …, n − 1`: `s = b[i]`, `s = s − l[i + k·n]·x[k]` for `k = 0, …, i − 1`,
   each product rounded before the subtraction, `r = s / l[i + i·n]`; if `r` is not finite, return
   `DIANA_ERR_OVERFLOW` (every input is finite by now); else `x[i] = r`.
3. Back, for `i = n − 1, …, 0`: `s = b[i]`, `s = s − l[k + i·n]·x[k]` for `k = n − 1` down to
   `i + 1`, then the same division and check. The products are subtracted in the order their
   unknowns were computed, which makes back substitution forward substitution on the mirrored
   system bit for bit (`fbwd` is `ffwd` of `L′[p, q] = L[n−1−q, n−1−p]`, `b′_p = b_{n−1−p}`).

A finite `r` certifies the whole row: once a product or partial sum is infinite or NaN, every later
partial sum and the quotient by a finite nonzero diagonal entry are too. So the one check per entry
makes every entry of `x` finite on `DIANA_OK`, and an overflow anywhere in a row is reported at that
row, after the rows before it have been written.

## Proof sketch

- **A1**: `fwd` is defined row by row (`solve` builds rows `0, …, m − 1`, `fwd L b i` reads row `i`
  of `solve L b (i + 1)`), and `fwd_eq` states the recurrence `xᵢ = row L b x i`; then
  `L[i, i]·xᵢ = bᵢ − Σ_{k<i} L[i, k]·xₖ` once `L[i, i] ≠ 0`.
- **A3**: strong induction on `i`. With `e = x − y`, A1 gives
  `L[i, i]·eᵢ = rᵢ − Σ_{k<i} L[i, k]·eₖ`, `r` the residual of `y`, so
  `|L[i, i]|·|eᵢ| ≤ ρᵢ + Σ_{k<i} |L[i, k]|·zₖ`, and the right side is `|L[i, i]|·zᵢ` by `fwd_eq`
  for `M(L)`. **A2** is A3 with `ρ = 0`, since `fwd M 0 = 0`.
- **A4–A6**: `bwd` is `fwd` on the mirrored system; `sum_mirror` reindexes
  `Σ_{q≤n−1−i} g(n − 1 − q) = Σ_{i≤k<n} g(k)`, and `cmp_mirror` gives `M(L′) = M(L)′` on the
  indices below `n`, so A4–A6 are A1–A3 on `L′`, `b′` and `ρ′` (`fwd_congr` for the comparison
  solve).
- **A7**: CHOLESKY-A1 and symmetry give `A[i, k] = Σ_{m<n} L[i, m]·L[k, m]` for `i, k < n`; then
  `Σₖ A[i, k]·xₖ = Σₘ L[i, m]·Σₖ L[k, m]·xₖ`, the inner sum is `yₘ` by A4 (the strict upper
  triangle of `chol A` is zero), and `Σ_{m≤i} L[i, m]·yₘ = bᵢ` by A1; the diagonal of `chol A` is
  `√pⱼ > 0`.
- **B1**: `row_error`, for `fl(fdotv g h c k / d)`: `fdotv` is Cholesky's `fdot` on the two-row
  matrix `(g, h)` (`fdotv_fdot`), so `Diana.Float.Cholesky.dot_error` gives the factor `F`,
  `|F − 1| ≤ γₖ`, for the `k` subtractions and products; the division is `div_error`,
  `x̂·d = s·(1 + δ) + e·d`, and `factor_div` absorbs `1 + δ` into `γₖ₊₁`. A finite `x̂ᵢ` makes `s`
  finite (`fdiv_finite_inv`), which is all `dot_error` needs. Proof: `forward_backward_error` in
  `verification/rocq/theory/Float/Substitution.v`.
- **B2**: A3 with `y = x̂` and `ρ` the bound of B1, row `i` taking `(i + 1)·u ≤ n·u < 1`.
- **B3**, **B4**: B1 and A6 on the mirrored system, with `sum_mirror` for the sums and `fbwd_eq`,
  the back recurrence in the C's order.
- **C1**, **C2**: the `/*@ ... */` annotations in the two sources. The nonlinear bounds
  `i + k·n < n·n` use the lemma `column_end` of `src/substitution_acsl.h` and an assertion
  `0 <= n * (n - 1 - j)` (with `j`, `i` or `k`) that instantiates it, as in CHOLESKY-C1 (WP-011);
  the shared validity and separation precondition is the predicate `substitution_valid`. The
  solve loop carries "every entry written so far is finite", from the contract of
  `diana_fp_finite`.
- **C3**: the three validation loops carry "every entry checked so far is finite" and "no diagonal
  entry so far is 0.0"; the solve loop keeps `x` as `lpre X ox n i` (written prefix, caller's
  suffix; `VST/Matrix.v`, shared with Cholesky), each store is `lpre_step` and each load `x[k]`,
  `k < i`, is `lpre_get`; `c_fdot_succ` and `c_fwd_eq` name the values. VST's `entailer!`
  substitutes `n := Zlength bl`, so the proof names the output lists with `set` before each
  `return`. Proof: `body_diana_forward_substitution` in
  `verification/rocq/theory/VST/ForwardSubstitution.v`.
- **C4**: the same validation, then `forward_while` over the decreasing `i`, keeping `x` as
  `lsuf Y ox n i` (caller's prefix, written suffix) with `lsuf_step` and `lsuf_get`, and an inner
  `forward_for` over the decreasing `k` whose sum after `t` steps is `c_bdot … t`, `t = n − 1 − k`
  (`c_bdot_succ`, `c_bwd_eq`). Proof: `body_diana_transpose_substitution` in
  `verification/rocq/theory/VST/TransposeSubstitution.v`.

## Model correspondence

- **Layer A** (`verification/lean/Diana/Real/Substitution.lean`,
  `verification/rocq/theory/Real/Substitution.v`): the matrix is a function `ℕ → ℕ → ℝ`; `row`,
  `solve`, `fwd`, `mirror`, `mirrorv`, `bwd` and `cmp` have the same definitions in both provers.
  Back sums are `Σ_{k ∈ [i, n)}` in Lean (`Finset.Ico`) and `sum (n − i) (fun t => … (i + t))` in
  Rocq, over the `sum` of `Diana.Real.Cholesky`, which A7 needs.
- **Layer B** (`verification/rocq/theory/Float/Substitution.v`): `fdotv`, `frow`, `fsolve`, `ffwd`,
  `fmirror`, `fmirrorv` and `fbwd` mirror layer A in binary64 with Cholesky's `fsub` (`Bminus`)
  and `Diana.Float.Sum`'s `fmul` and `fdiv`, in `mode_NE` and parameterised by the NaN-payload
  functions; `rmat` and `rvec` read the binary64 data as reals for B2 and B4.
- **Layer C, VST** (`verification/rocq/theory/VST/ForwardSubstitution.v` and
  `TransposeSubstitution.v` against `verification/clight/forward_substitution_aarch64_macos.v` and
  `transpose_substitution_aarch64_macos.v`, CompCert target AArch64 macOS; models in the AST-free
  `verification/rocq/theory/VST/Substitution.v`): `c_fwd` and `c_bwd` are `ffwd` and `fbwd`
  instantiated with CompCert's `Float.binop_nan`, so `fsub`, `fmul` and `fdiv` are `Float.sub`,
  `Float.mul` and `Float.div` by conversion, at `L i k = Znth (i + k·n) ll` and `b i = Znth i bl`.
  `diag_nonzero` is the C test `Float.cmp Ceq … Float.zero = false`; `diag_real` turns it, for a
  finite entry, into the nonzero real of B1–B4.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| SUBSTITUTION-A1 | proved | proved | – |
| SUBSTITUTION-A2 | proved | proved | – |
| SUBSTITUTION-A3 | proved | proved | – |
| SUBSTITUTION-A4 | proved | proved | – |
| SUBSTITUTION-A5 | proved | proved | – |
| SUBSTITUTION-A6 | proved | proved | – |
| SUBSTITUTION-A7 | proved | proved | – |
| SUBSTITUTION-B1 | – | proved | – |
| SUBSTITUTION-B2 | – | proved | – |
| SUBSTITUTION-B3 | – | proved | – |
| SUBSTITUTION-B4 | – | proved | – |
| SUBSTITUTION-C1 | – | – | 109/109 goals (Frama-C 32.1, Alt-Ergo 2.6.4) |
| SUBSTITUTION-C2 | – | – | 110/110 goals (Frama-C 32.1, Alt-Ergo 2.6.4) |
| SUBSTITUTION-C3 | – | proved | – |
| SUBSTITUTION-C4 | – | proved | – |
| SUBSTITUTION-C5 | – | proved | – |
| SUBSTITUTION-C6 | – | proved | – |
