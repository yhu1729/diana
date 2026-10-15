---
method: trapezoidal
kernel: src/trapezoidal.c
model: >
  trapezoidal y h : ℝ for n ≥ 2 samples y₀, …, yₙ₋₁ with spacing h:
  T = h·((y₀ + yₙ₋₁)/2 + Σ_{i=1}^{n−2} yᵢ). The binary64 model evaluates s₀ = 0.5·(y₀ + yₙ₋₁), then
  sₖ = sₖ₋₁ + yₖ for k = 1, …, n − 2, and returns h·sₙ₋₂, each operation rounded to nearest-even.
hypothesis:
  - "H1: f has derivative f′ and f′ has derivative f″ at every point of [a, b] (two-sided), and |f″| ≤ M₂ there; continuity of f″ is not required"
  - "H2: a ≤ b, m ≥ 1 panels, h = (b − a)/m, yᵢ = f(a + i·h) for i = 0, …, m (n = m + 1 samples)"
  - "H3 (float layers): yᵢ and h are arbitrary binary64 values supplied by the caller; n·u < 1 with u = 2⁻⁵³"
theorem:
  - id: TRAPEZOIDAL-A1
    layer: A
    informal: "local error: under H1 on [x, x + h] with h ≥ 0, |∫ₓ^{x+h} f − h·(f(x) + f(x + h))/2| ≤ M₂·h³/12"
    lean: Diana.Real.Trapezoidal.local_error
    rocq: Diana.Real.Trapezoidal.local_error
  - id: TRAPEZOIDAL-A2
    layer: A
    informal: "composite error: under H1 and H2, |∫ₐᵇ f − T| ≤ (b − a)·h²·M₂/12"
    lean: Diana.Real.Trapezoidal.composite_error
    rocq: Diana.Real.Trapezoidal.composite_error
  - id: TRAPEZOIDAL-B1
    layer: B
    informal: >
      a finite result certifies the whole evaluation: if the binary64 model returns a finite value,
      then h, every yᵢ and every partial sum sₖ are finite and no operation overflowed, so each
      operation returned the rounded exact value. This is why the kernel checks only its result.
    rocq: Diana.Float.Trapezoidal.finite_result
  - id: TRAPEZOIDAL-B2
    layer: B
    informal: >
      forward error: if the binary64 model returns a finite r and n·u < 1, then
      |r − T| ≤ γₙ·|h|·A + (1 + γₙ₋₁)·|h|·η + η, with A = |y₀ + yₙ₋₁|/2 + Σ_{i=1}^{n−2} |yᵢ|,
      γₖ = k·u/(1 − k·u), u = 2⁻⁵³ and η = 2⁻¹⁰⁷⁵ (underflow in the halving and the final product).
    rocq: Diana.Float.Trapezoidal.forward_error
  - id: TRAPEZOIDAL-C1
    layer: C
    informal: >
      ACSL contract in src/trapezoidal.c, Frama-C WP float model with RTE: memory safety (only
      y[0 .. n−1] is read, only *result is written), no UB, loop termination, DIANA_OK only for
      non-NULL y and result with n ≥ 2 and then *result finite, and *result untouched on
      DIANA_ERR_ARG. No assumed contract.
    acsl: src/trapezoidal.c
  - id: TRAPEZOIDAL-C2
    layer: C
    informal: >
      diana_trapezoidal computes the binary64 model (VST, AArch64 macOS Clight AST): it returns
      DIANA_OK and writes the model value exactly when y and result are non-NULL, n ≥ 2 and the
      model value is finite, and returns DIANA_ERR_ARG without writing otherwise.
    rocq: Diana.VST.Trapezoidal.body_diana_trapezoidal
---
# trapezoidal

Composite trapezoidal rule over tabulated samples. The kernel never calls `f`: the caller supplies
`yᵢ ≈ f(a + i·h)` and the spacing `h`, and owns the sampling error. `diana_trapezoidal(y, n, h,
&result)` needs `n ≥ 2`; `h` may have either sign (a negative `h` integrates from `b` down to `a`,
which reverses the samples and negates the result, so the layer-A theorems take `a ≤ b`).

## Proof sketch

- **A1**: let `E(s) = ∫ₓ^{x+s} f − s·(f(x) + f(x + s))/2`. Then `E(0) = 0`,
  `E′(s) = (f(x + s) − f(x))/2 − s·f′(x + s)/2` (fundamental theorem of calculus, `f` continuous
  because differentiable), `E′(0) = 0`, and `E″(s) = −s·f″(x + s)/2`. Two applications of the mean
  value inequality against the boundary functions `M₂·s²/4` and `M₂·s³/12` give the bound, so f″
  needs only to exist and be bounded (Mathlib
  `image_norm_le_of_norm_deriv_right_le_deriv_boundary`; Coquelicot `is_derive` with Stdlib `MVT`).
  Lean differentiates the integral of the clamped extension `t ↦ f(max x (min t (x + h)))`, which
  is continuous on ℝ, so the fundamental theorem of calculus holds at both endpoints without any
  assumption on `f` outside `[x, x + h]`.
  Shared with Simpson, whose error term needs the same scheme to the fourth derivative.
- **A2**: additivity of the integral over the `m` panels (Mathlib
  `intervalIntegral.sum_integral_adjacent_intervals`; Coquelicot `RInt_Chasles`), A1 on each, and
  `m·h = b − a`.
- **B1**: in round-to-nearest-even, `Bplus` and `Bmult` return a non-finite value whenever an
  operand is non-finite (`∞ − ∞` and `0·∞` are NaN) and whenever the rounded exact result exceeds
  `DBL_MAX` (`Bplus_correct`/`Bmult_correct`, overflow branch). Induction on the partial sums.
- **B2**: Higham's recursive-summation argument with Flocq's relative-error lemmas. Sums of two
  binary64 values have relative error at most `u` even below the normal range, because an addition
  that lands in the subnormal range is exact (`FLT_plus_error_N_ex`); the halving and the final
  product have relative error `u` plus absolute error `η` (`error_N_FLT`). With `ŝ` the computed
  sum and `S` the exact one, `|ŝ − S| ≤ γₙ₋₁·A + (1 + γₙ₋₂)·η`, then
  `|r − h·S| ≤ u·|h|·|S| + (1 + u)·|h|·|ŝ − S| + η` and `|S| ≤ A`; the constants collapse through
  `γₖ·(1 + u) + u ≤ γₖ₊₁`. B1 supplies the no-overflow premise of every step.
- **C1**: the `/*@ ... */` annotations in `src/trapezoidal.c`. The loop invariant is only
  `1 <= i <= n - 1`; WP proves no value property beyond finiteness on `DIANA_OK`, see below.
- **C2**: one Clight loop over a read-only `tarray tdouble n`; `size_t` is `tulong` on the target,
  so the index lives in `Int64`. Invariant: `s` is the model partial sum `sᵢ₋₁`.

## Composition

For samples `ỹᵢ` of `f(a + i·h)` with `|ỹᵢ − f(a + i·h)| ≤ δᵢ`, A2, B2 and the linearity of `T`
give `|r − ∫ₐᵇ f| ≤ (b − a)·h²·M₂/12 + γₙ·|h|·A + (1 + γₙ₋₁)·|h|·η + η + |h|·Σ′ δᵢ` (`Σ′`: the
trapezoidal weights, ½ at both ends). Only the first three terms are Diana's; `δᵢ` includes the
rounding of the nodes `a + i·h`, which the caller computes.

## Why the functional contract is not in ACSL

WP's float model gives C operations their IEEE semantics, but an ACSL cast `(double)(x)` is
`to_f64`, which maps every real above `DBL_MAX` to infinity, while IEEE round-to-nearest maps sums
in `(DBL_MAX, DBL_MAX + ulp/2)` to `DBL_MAX`. A post-condition `*result == (double)(h * …)` over
an ACSL recursive sum is therefore false at the overflow boundary; tried on this kernel, Alt-Ergo
2.6.4 did not prove even `s == (double)((double)0.5 * (double)(y[0] + y[n - 1]))` right after the
C assignment. The value claim is TRAPEZOIDAL-C2 (VST), on the same Flocq model as B1 and B2.

## What the theorems do not say

- Nothing about cancellation: B2 is relative to `A`, not to `|T|`. When `|T| ≪ A` the relative
  error of `r` can be large; compensated summation would be a different kernel.
- `n·u < 1` holds for every array that fits in memory with `n < 2⁵³`; B2 is vacuous beyond it.
- Spacing is uniform; non-uniform nodes need a different kernel.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| TRAPEZOIDAL-A1 | proved | planned | – |
| TRAPEZOIDAL-A2 | proved | planned | – |
| TRAPEZOIDAL-B1 | – | planned | – |
| TRAPEZOIDAL-B2 | – | planned | – |
| TRAPEZOIDAL-C1 | – | – | 41/41 goals (Frama-C 33.0, Alt-Ergo 2.6.4), no assumed contract |
| TRAPEZOIDAL-C2 | – | planned | – |
