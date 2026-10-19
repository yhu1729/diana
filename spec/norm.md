---
method: norm
kernel: [src/norm_1.c, src/norm_2.c, src/norm_inf.c]
model: >
  For a vector x of n reals: norm1 x = Σ |xᵢ|, norm2 x = √(Σ xᵢ²) and norm_inf x = max |xᵢ| (0 for
  n = 0). The binary64 models follow the C: the 1-norm adds fl(0 + |x₀|), then |xᵢ| for
  i = 1, …, n − 1 in order; the maximum norm keeps m = |xᵢ| whenever |xᵢ| > m, from m = +0, which
  is exact; the 2-norm finds m = max |xᵢ| at its first index k in that pass, returns +0 when
  m = 0, and otherwise evaluates s = 1, then s = fl(s + fl(q·q)) with q = fl(xᵢ/m) for i ≠ k in
  index order, and returns fl(m·fl(√s)), each operation rounded to nearest-even (no fused
  multiply-add).
hypothesis:
  - "H1: x is a list of reals; A4 takes x and y of equal length"
  - "H2 (float layers): the entries are arbitrary binary64 values; every layer-B theorem takes them all finite, the condition of the C's DIANA_OK and DIANA_ERR_OVERFLOW, and the error and overflow bounds take k·u < 1 for the k of their γ, u = 2⁻⁵³"
theorem:
  - id: NORM-A1
    layer: A
    informal: >
      the scaled 2-norm is the 2-norm: for k < n with xₖ ≠ 0 and m = |xₖ|,
      m·√(1 + Σ_{i≠k} (xᵢ/m)²) = √(Σ xᵢ²), the exact-arithmetic value of diana_norm_2
    lean: Diana.Real.Norm.scale
    rocq: Diana.Real.Norm.scale
  - id: NORM-A2
    layer: A
    informal: "equivalence: ‖x‖∞ ≤ ‖x‖₂ ≤ ‖x‖₁ ≤ n·‖x‖∞"
    lean: Diana.Real.Norm.equiv
    rocq: Diana.Real.Norm.equiv
  - id: NORM-A3
    layer: A
    informal: "Cauchy–Schwarz bounds: ‖x‖₁ ≤ √n·‖x‖₂ and ‖x‖₂ ≤ √n·‖x‖∞"
    lean: Diana.Real.Norm.cauchy
    rocq: Diana.Real.Norm.cauchy
  - id: NORM-A4
    layer: A
    informal: "triangle inequality: ‖x + y‖ ≤ ‖x‖ + ‖y‖ for each of the three norms, x and y of equal length"
    lean: Diana.Real.Norm.triangle
    rocq: Diana.Real.Norm.triangle
  - id: NORM-A5
    layer: A
    informal: "absolute homogeneity: ‖c·x‖ = |c|·‖x‖ for each of the three norms"
    lean: Diana.Real.Norm.homogeneous
    rocq: Diana.Real.Norm.homogeneous
  - id: NORM-A6
    layer: A
    informal: "definiteness: each of the three norms is 0 exactly when every xᵢ is 0"
    lean: Diana.Real.Norm.definite
    rocq: Diana.Real.Norm.definite
  - id: NORM-B1
    layer: B
    informal: >
      the maximum norm is exact: with every entry finite, the binary64 model returns a finite
      value r with r = max |xᵢ| (0 for n = 0), so diana_norm_inf never overflows.
    rocq: Diana.Float.Norm.norm_inf_exact
  - id: NORM-B2
    layer: B
    informal: >
      forward error of the 1-norm: with every entry finite, a finite result r and (n − 1)·u < 1,
      |r − ‖x‖₁| ≤ γₙ₋₁·‖x‖₁, γₖ = k·u/(1 − k·u), u = 2⁻⁵³. The first addition is exact and a sum
      of binary64 values has relative error u also below the normal range, so there is no
      absolute term.
    rocq: Diana.Float.Norm.norm1_error
  - id: NORM-B3
    layer: B
    informal: >
      no spurious overflow in the 1-norm: with every entry finite and (n − 1)·u < 1, the result is
      finite whenever (1 + γₙ₋₁)·‖x‖₁ ≤ DBL_MAX; DIANA_ERR_OVERFLOW means ‖x‖₁ is within that
      factor of DBL_MAX or above it.
    rocq: Diana.Float.Norm.norm1_finite
  - id: NORM-B4
    layer: B
    informal: >
      forward error of the 2-norm: with every entry finite, a finite result r and (n + 5)·u < 1,
      |r − ‖x‖₂| ≤ γₙ₊₅·‖x‖₂ + η, η = 2⁻¹⁰⁷⁵ (underflow in the final product m·√s; the
      underflow of the quotients and squares is absorbed into γ because s ≥ 1).
    rocq: Diana.Float.Norm.norm2_error
  - id: NORM-B5
    layer: B
    informal: >
      no spurious overflow in the 2-norm: with every entry finite and (n + 4)·u < 1, the result
      is finite whenever (1 + γₙ₊₄)·‖x‖₂ ≤ DBL_MAX; no quotient, square or partial sum can
      overflow, only the final product.
    rocq: Diana.Float.Norm.norm2_finite
  - id: NORM-B6
    layer: B
    informal: >
      the 2-norm is at least the largest magnitude: with every entry finite and a finite result
      r, ‖x‖∞ ≤ r, so a nonzero vector never has a zero 2-norm (no underflow to zero).
    rocq: Diana.Float.Norm.norm2_lower
  - id: NORM-C1
    layer: C
    informal: >
      ACSL contract in src/norm_1.c, Frama-C WP float model with RTE: memory safety (only
      x[0 .. n−1] is read, only *result is written), no UB, termination, a status in {DIANA_OK,
      DIANA_ERR_ARG, DIANA_ERR_OVERFLOW}; DIANA_OK only for non-NULL pointers and every x[q]
      finite, and then *result finite and ≥ 0, and 0 for n = 0; DIANA_ERR_OVERFLOW only for
      non-NULL pointers and every x[q] finite; DIANA_ERR_ARG only for a NULL pointer or a
      non-finite x[q]; *result untouched on both errors. No assumed contract.
    acsl: src/norm_1.c
  - id: NORM-C2
    layer: C
    informal: >
      ACSL contract in src/norm_2.c with the clauses of C1 except the sign, and on DIANA_OK
      |x[q]| ≤ *result for every q < n. The sum of squares starts at 1 and stays ≥ 1 (an IEEE
      comparison in the loop invariant), which meets the precondition of diana_fp_sqrt, the only
      assumed contract (src/fp_sqrt.h, SKIP), discharged by CHOLESKY-B1.
    acsl: src/norm_2.c
  - id: NORM-C3
    layer: C
    informal: >
      ACSL contract in src/norm_inf.c, the full functional contract: memory safety, no UB,
      termination, a status in {DIANA_OK, DIANA_ERR_ARG}, DIANA_ERR_ARG exactly for a NULL
      pointer or a non-finite x[q] with *result untouched, and on DIANA_OK every x[q] finite,
      *result finite, ≥ 0, ≥ |x[q]| for every q < n and equal to 0 or to some |x[q]|. No assumed
      contract.
    acsl: src/norm_inf.c
  - id: NORM-C4
    layer: C
    informal: >
      diana_norm_1 computes the binary64 model (VST, AArch64 macOS Clight AST): for x pointing to
      n ≥ 1 readable doubles and a writable *result separate from them, it returns DIANA_OK,
      writing the model value, when every entry and that value are finite; DIANA_ERR_OVERFLOW
      when every entry is finite and the value is not; DIANA_ERR_ARG when an entry is not finite;
      *result unchanged on both errors. The NULL and n = 0 paths are C1.
    rocq: Diana.VST.Norm1.body_diana_norm_1
  - id: NORM-C5
    layer: C
    informal: >
      diana_norm_2 computes the binary64 model with the statuses of C4 (VST, AArch64 macOS
      Clight AST), importing the funspec of diana_fp_sqrt proved in CHOLESKY-C2. The NULL and
      n = 0 paths are C2.
    rocq: Diana.VST.Norm2.body_diana_norm_2
  - id: NORM-C6
    layer: C
    informal: >
      diana_norm_inf computes the binary64 model (VST, AArch64 macOS Clight AST): DIANA_OK with
      the model value written when every entry is finite, otherwise DIANA_ERR_ARG with *result
      unchanged. The NULL and n = 0 paths are C3.
    rocq: Diana.VST.NormInf.body_diana_norm_inf
  - id: NORM-C7
    layer: C
    informal: >
      the copy of diana_fp_finite in the Clight AST of norm_1 implements its IEEE semantics, as
      BISECTION-C5 for the copy in bisection_init (VST, AArch64 macOS Clight AST).
    rocq: Diana.VST.Norm1.body_diana_fp_finite
  - id: NORM-C8
    layer: C
    informal: >
      the copy of diana_fp_abs in the Clight AST of norm_1 returns x < 0.0 ? −x : x (VST, AArch64
      macOS Clight AST), which is |x| for finite x.
    rocq: Diana.VST.Norm1.body_diana_fp_abs
  - id: NORM-C9
    layer: C
    informal: "the copy of diana_fp_finite in the Clight AST of norm_2, as C7"
    rocq: Diana.VST.Norm2.body_diana_fp_finite
  - id: NORM-C10
    layer: C
    informal: "the copy of diana_fp_abs in the Clight AST of norm_2, as C8"
    rocq: Diana.VST.Norm2.body_diana_fp_abs
  - id: NORM-C11
    layer: C
    informal: "the copy of diana_fp_finite in the Clight AST of norm_inf, as C7"
    rocq: Diana.VST.NormInf.body_diana_fp_finite
  - id: NORM-C12
    layer: C
    informal: "the copy of diana_fp_abs in the Clight AST of norm_inf, as C8"
    rocq: Diana.VST.NormInf.body_diana_fp_abs
---
# norm

Vector norms of `n` doubles: `diana_norm_1` (`Σ |xᵢ|`), `diana_norm_2` (`√(Σ xᵢ²)`) and
`diana_norm_inf` (`max |xᵢ|`), each `(x, n, &result)`. `n = 0` is the empty vector, norm `+0`.
The 2-norm scales by the largest magnitude, so it neither overflows nor underflows unless the norm
itself is out of range.

## Operation order

The binary64 model, and every layer that follows it, is the order of the C:

1. `x` or `result` NULL: `DIANA_ERR_ARG`, nothing read or written.
2. One pass over `x[0], …, x[n−1]`: a non-finite entry returns `DIANA_ERR_ARG` at once with
   `*result` untouched; otherwise `a = |x[i]|` (`diana_fp_abs`, `x < 0.0 ? −x : x`) and
   - 1-norm: `s = s + a` from `s = +0`;
   - maximum norm: `m = a` if `a > m`, from `m = +0`;
   - 2-norm: as the maximum norm, also recording `k = i` when `m` changes, so `k` is the first
     index of the largest magnitude.
3. 1-norm: `s` not finite is `DIANA_ERR_OVERFLOW`; maximum norm: `m` is the result.
4. 2-norm: `m == 0.0` writes `+0`. Otherwise `s = 1`, then for `i ≠ k` in index order
   `q = x[i] / m` and `s = s + q·q`; `t = diana_fp_sqrt(s)`, `r = m·t`; `r` not finite is
   `DIANA_ERR_OVERFLOW`.

Every error leaves `*result` untouched, and a non-finite entry is `DIANA_ERR_ARG` even after the
sum has overflowed. Since `|x[i]| ≤ m`, each quotient and square lies in `[−1, 1]` and `[0, 1]`
and `1 ≤ s ≤ n`: only the final product can overflow, and `r ≥ m` (B6).

## Proof sketch

- **A1**: `sumsq x = x_k² + sumsq (remove k x)` (split `x` at `k`), `Σ (xᵢ/m)² = Σ xᵢ²/m²`, and
  `m·√(1 + S/m²) = √(m² + S)`. In Rocq `remove k x = firstn k x ++ skipn (S k) x`, in Lean
  `List.eraseIdx`.
- **A2**: by induction on the list: `|a| ≤ √(a² + S)`, `S ≤ N²` for the 1-norm `N`, and
  `|a| + N ≤ (1 + n)·max`.
- **A3**: by induction, from `2·d ≤ p + q` whenever `0 ≤ p`, `0 ≤ q` and `d² ≤ p·q`
  (`two_mul_le` in Rocq; `cs2`, the two-term Cauchy–Schwarz inequality, in Lean) with
  `p = n·a²`, `q = S`, `d = |a|·N`.
- **A4**: entrywise for the 1- and maximum norms; for the 2-norm,
  `Σ (xᵢ + yᵢ)² = Σ xᵢ² + 2·Σ xᵢyᵢ + Σ yᵢ²` and Cauchy–Schwarz `(Σ xᵢyᵢ)² ≤ Σ xᵢ²·Σ yᵢ²`
  (`dot_sq_le`, the step of the Lagrange identity).
- **A5**, **A6**: by induction; `√(c²·S) = |c|·√S` and `Rmax (c·a) (c·b) = c·Rmax a b` for
  `c ≥ 0`.
- **B1**: on finite operands the comparison `a > m` is the real one (`fgtb_real` of
  `Diana.Float.LU`) and `|x|` is `fmag` (`fmag_finite`), so the fold is the real maximum
  (`fold_fmax`). Proof: `norm_inf_exact` in `verification/rocq/theory/Float/Norm.v`.
- **B2**: `nonneg_step`: for nonnegative terms, a partial sum within `γⱼ·X` of the exact `X`
  stays within `γⱼ₊₁` of the next exact sum (`add_error` and `gamma_step`); `fold_nonneg`
  inducts on it. `0 + |x₀|` is exact (`fadd_zero_l`), so `n − 1` roundings remain. Proof:
  `norm1_error`.
- **B3**: the same induction on the real rounding of each partial sum, bounded by
  `(1 + γ)·‖x‖₁ ≤ DBL_MAX < 2¹⁰²⁴`, gives every `Bplus` finite (`fadd_finite_iff`,
  `fold_nonneg_finite`). Proof: `norm1_finite`.
- **B4**: `fscale_spec` identifies `m` with `‖x‖∞` (B1) and `k` with an index of it. Each term
  satisfies `|fl(fl(xᵢ/m)²) − (xᵢ/m)²| ≤ γ₃·(xᵢ/m)² + 5η` (`sq_spec`: three relative factors by
  `factor_mul` of `Diana.Float.Cholesky`, the absolute errors of the quotient and the square);
  the sum from 1 has `n − 1` more roundings (`fold_nonneg`), so with `S = 1 + Σ_{i≠k} (xᵢ/m)²`,
  `|ŝ − S| ≤ (γₙ₊₂ + u)·S ≤ γₙ₊₃·S` (`sum_error`: `gamma_add`, and `absorb`, which bounds
  `(1 + γₙ₋₁)·5(n − 1)η ≤ u ≤ u·S` from `n < 2⁵³`, `gap`). Then `|√(ŝ/S) − 1| ≤ |ŝ/S − 1|`
  (`sqrt_one_error`), the root and the product add one factor each (`sqrt_error`,
  `round_error`), and A1 identifies `m·√S` with `‖x‖₂` (`root_error`). Proof: `norm2_error`.
- **B5**: `fold_nonneg_finite` with `1 + Σ fl(q²) ≤ n ≤ 1/u` and `1 + γₙ₋₁ ≤ 1/u` keeps the sum
  below `2¹⁰⁶`; `root_error` bounds `m·t ≤ (1 + γₙ₊₄)·‖x‖₂ ≤ DBL_MAX`, and rounding is monotone
  with `DBL_MAX` representable. Proof: `norm2_finite`.
- **B6**: rounding is monotone and `1`, `m` are representable: `ŝ ≥ 1` (`fold_ge`), `t ≥ 1`
  (`sqrt_ge_one`), `fl(m·t) ≥ m`. Proof: `norm2_lower`.
- **C1–C3**: the `/*@ ... */` annotations in `src/norm_1.c`, `src/norm_2.c` and
  `src/norm_inf.c`. The loops carry "every entry so far is finite" and, for the maximum, the
  bound and witness of the running maximum (`m == 0.0` or `m == |x[k]|`, `k < i`). The 2-norm's
  second loop keeps `\ge_double(s, 1.0)`, which Alt-Ergo proves through the IEEE addition, and
  after the call the chain `t` finite, `s` finite, `t ≥ 1`, `m·t ≥ m`,
  `r == \round_double(\NearestEven, m * t)`, `\round_double(\NearestEven, m) == m` gives
  `r ≥ m`; with a cast `(double)(m * t)` in place of `\round_double` Alt-Ergo fails, since the
  cast is `to_f64`, which has no monotonicity axiom (WP-014). The existential of C3 names
  `\old(x[q])`, which Alt-Ergo matches with the loop invariant; stated on `x[q]` after the write
  to `*result`, the goal timed out.
- **C4–C6**: the loops keep the C local equal to the model of the prefix
  `sublist 0 i xs` (`c_norm1_succ`, `c_norm_inf_succ`, `c_scale_succ`, `c_sumsq_succ`), and
  `forallb is_finite (sublist 0 i xs)` as in `VST/Trapezoidal.v`; a failing `diana_fp_finite`
  returns with `forallb_false`. The 2-norm's second loop keeps
  `s = c_sumsq m (remove k (sublist 0 i xs))`, and `remove_snoc` shows that appending `x[i]` to
  the prefix appends it to the removed list unless `i = k`. The models of
  `verification/rocq/theory/VST/Norm.v` equal the layer-B ones (`c_norm1_model`,
  `c_norm2_model`, `c_norm_inf_model`). The specs take `n ≥ 1`: the C compares `x` with NULL,
  and a zero-length `data_at` gives no valid pointer for the comparison, so `n = 0` is left to
  WP with the NULL paths. Proofs: `body_diana_norm_1`, `body_diana_norm_2`,
  `body_diana_norm_inf` in `verification/rocq/theory/VST/Norm1.v`, `Norm2.v` and `NormInf.v`.

## Model correspondence

- **Layer A** (`verification/lean/Diana/Real/Norm.lean`, `verification/rocq/theory/Real/Norm.v`):
  vectors are lists of reals; `norm1`, `sumsq`, `norm2` and `norm_inf` (Lean `normInf`) are the
  same recursions in both provers, the entrywise sum is `add` in Rocq and
  `List.zipWith (· + ·)` in Lean.
- **Layer B** (`verification/rocq/theory/Float/Norm.v`): `fnorm1`, `fnorm_inf`, `fscale`,
  `fsumsq` and `fnorm2` over `list b64` with `fadd`, `fmul`, `fdiv` (`Diana.Float.Sum`), `fsqrt`
  (`Diana.Float.Cholesky`), `fmag`, `fgtb` and `feqb` (`Diana.Float.LU`, the C's magnitude and
  comparisons), parameterised by the NaN-payload functions. The theorems are stated against the
  layer-A functions applied to `map B2R xs`.
- **Layer C, VST** (`verification/rocq/theory/VST/Norm1.v`, `Norm2.v`, `NormInf.v` against
  `verification/clight/norm_1_aarch64_macos.v`, `norm_2_…` and `norm_inf_…`, CompCert target
  AArch64 macOS): `c_norm1`, `c_norm2` and `c_norm_inf` in the AST-free `VST/Norm.v` use
  `Float.add`, `Float.mul`, `Float.div`, `Float.sqrt`, `Float.cmp` and the `diana_fp_abs` model
  `c_abs` of `VST/Bisection.v`, with the constants `0.0` and `1.0` as clightgen writes them.

## What the theorems do not say

- Nothing about cancellation in a sum of signed values: every term of the 1-norm and the 2-norm
  is nonnegative, so the bounds are relative to the norm itself.
- The 2-norm bound `γₙ₊₅` is about twice the classical `(n/2 + 1)·u`: the square root step uses
  `|√z − 1| ≤ |z − 1|` rather than half of it.
- The order is fixed and uncompensated; pairwise or compensated summation would be another
  kernel.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| NORM-A1 | proved | proved | – |
| NORM-A2 | proved | proved | – |
| NORM-A3 | proved | proved | – |
| NORM-A4 | proved | proved | – |
| NORM-A5 | proved | proved | – |
| NORM-A6 | proved | proved | – |
| NORM-B1 | – | proved | – |
| NORM-B2 | – | proved | – |
| NORM-B3 | – | proved | – |
| NORM-B4 | – | proved | – |
| NORM-B5 | – | proved | – |
| NORM-B6 | – | proved | – |
| NORM-C1 | – | – | 53/53 goals (Frama-C 32.1, Alt-Ergo 2.6.4), no assumed contract |
| NORM-C2 | – | – | 90/90 goals (Frama-C 32.1, Alt-Ergo 2.6.4), assumed contract of diana_fp_sqrt (CHOLESKY-B1) |
| NORM-C3 | – | – | 54/54 goals (Frama-C 32.1, Alt-Ergo 2.6.4), no assumed contract |
| NORM-C4 | – | proved | – |
| NORM-C5 | – | proved | – |
| NORM-C6 | – | proved | – |
| NORM-C7 | – | proved | – |
| NORM-C8 | – | proved | – |
| NORM-C9 | – | proved | – |
| NORM-C10 | – | proved | – |
| NORM-C11 | – | proved | – |
| NORM-C12 | – | proved | – |
