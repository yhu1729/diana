---
method: simpson
kernel: src/simpson.c
model: >
  simpson y h : ℝ for n = 2p + 1 ≥ 3 samples y₀, …, yₙ₋₁ with spacing h:
  S = (h/3)·(y₀ + yₙ₋₁ + 4·Σ_{k=0}^{p−1} y₂ₖ₊₁ + 2·Σ_{k=1}^{p−1} y₂ₖ). The binary64 model evaluates
  sₒ = 0 + y₁ + y₃ + … + yₙ₋₂ and sₑ = 0 + y₂ + y₄ + … + yₙ₋₃, each left to right from +0, then
  s = ((y₀ + yₙ₋₁) + 4·sₒ) + 2·sₑ and returns (h·s)/3, each operation rounded to nearest-even.
hypothesis:
  - "H1: f, f′, f″ and f‴ have two-sided derivatives at every point of [a, b], and |f⁗| ≤ M₄ there; continuity of f⁗ is not required"
  - "H2: a ≤ b, m = 2p panels with p ≥ 1, h = (b − a)/m, yᵢ = f(a + i·h) for i = 0, …, m (n = m + 1 samples)"
  - "H3 (float layers): yᵢ and h are arbitrary binary64 values supplied by the caller; n·u < 1 with u = 2⁻⁵³"
theorem:
  - id: SIMPSON-A1
    layer: A
    informal: "local error: under H1 on [x, x + 2h] with h ≥ 0, |∫ₓ^{x+2h} f − (h/3)·(f(x) + 4·f(x + h) + f(x + 2h))| ≤ M₄·h⁵/90"
    lean: Diana.Real.Simpson.local_error
    rocq: Diana.Real.Simpson.local_error
  - id: SIMPSON-A2
    layer: A
    informal: "composite error: under H1 and H2, |∫ₐᵇ f − S| ≤ (b − a)·h⁴·M₄/180"
    lean: Diana.Real.Simpson.composite_error
    rocq: Diana.Real.Simpson.composite_error
  - id: SIMPSON-B1
    layer: B
    informal: >
      a finite result certifies the whole evaluation: if the binary64 model returns a finite value,
      then h, y₀, yₙ₋₁, every odd and every even interior yᵢ, and every partial sum of sₒ and sₑ
      are finite; since a finite Bplus, Bmult or Bdiv of finite operands is the rounded exact
      value (fadd_value, fmul_value, fdiv_value), no operation overflowed. This is why the kernel
      checks only its result.
    rocq: Diana.Float.Simpson.finite_result
  - id: SIMPSON-B2
    layer: B
    informal: >
      forward error: if the binary64 model returns a finite r, the even list is no longer than the
      odd one (as the kernel's are) and (p + 5)·u < 1, then
      |r − h·S′/3| ≤ γₚ₊₅·|h|·A/3 + (1 + u)·η/3 + η, with S′ = y₀ + yₙ₋₁ + 4·Σ y₂ₖ₊₁ + 2·Σ y₂ₖ the
      exact weighted sum, A = |y₀ + yₙ₋₁| + 4·Σ|y₂ₖ₊₁| + 2·Σ|y₂ₖ|, γₖ = k·u/(1 − k·u), u = 2⁻⁵³ and
      η = 2⁻¹⁰⁷⁵ (underflow in the product with h and in the division by 3).
    rocq: Diana.Float.Simpson.forward_error
  - id: SIMPSON-C1
    layer: C
    informal: >
      ACSL contract in src/simpson.c, Frama-C WP float model with RTE: memory safety (only
      y[0 .. n−1] is read, only *result is written), no UB, termination of both loops, DIANA_OK
      only for non-NULL y and result with n ≥ 3 odd and then *result finite, and *result
      untouched on DIANA_ERR_ARG. No assumed contract.
    acsl: src/simpson.c
  - id: SIMPSON-C2
    layer: C
    informal: >
      diana_simpson computes the binary64 model (VST, AArch64 macOS Clight AST): for y pointing to
      an odd number n ≥ 3 of readable doubles and a writable *result separate from them, it returns
      DIANA_OK and writes the model value when that value is finite, and returns DIANA_ERR_ARG
      leaving *result unchanged otherwise. The NULL, n < 3 and even-n paths are SIMPSON-C1.
    rocq: Diana.VST.Simpson.body_diana_simpson
---
# simpson

Composite Simpson rule over tabulated samples. As for the trapezoidal rule, the kernel never calls
`f`: the caller supplies `yᵢ ≈ f(a + i·h)` and the spacing `h`. `diana_simpson(y, n, h, &result)`
needs an odd `n ≥ 3`, that is an even number `n − 1` of panels; `h` may have either sign.

## Operation order

The binary64 model, and every layer that follows it, is the order of the C:

1. `sₒ = +0`, then `sₒ = sₒ + y[2k + 1]` for `k = 0, …, p − 1` (the odd samples, left to right);
2. `sₑ = +0`, then `sₑ = sₑ + y[2k]` for `k = 1, …, p − 1` (the even interior samples);
3. `s = ((y[0] + y[n − 1]) + 4·sₒ) + 2·sₑ`;
4. `r = (h·s)/3`, a correctly rounded division rather than a product with a rounded `1/3`.

The two sums are independent, so fusing the loops would not change a bit. The products `4·sₒ` and
`2·sₑ` are exact unless they overflow. The kernel checks only `r`: a NaN or infinite sample or `h`,
or an overflow in any operation, makes `r` non-finite and the call returns `DIANA_ERR_ARG`. One
range limit follows from the order: `h·s` can overflow when `h·S/3` would not (a test pins it).

## Proof sketch

- **A1**: about the midpoint `c = x + h`, let
  `E(s) = ∫_{c−s}^{c+s} f − (s/3)·(f(c − s) + 4·f(c) + f(c + s))` for `0 ≤ s ≤ h`. Then
  `E′(s) = (2/3)(f(c+s) + f(c−s)) − (4/3)f(c) − (s/3)(f′(c+s) − f′(c−s))`,
  `E″(s) = (1/3)(f′(c+s) − f′(c−s)) − (s/3)(f″(c+s) + f″(c−s))` and
  `E‴(s) = −(s/3)(f‴(c+s) − f‴(c−s))`, all four zero at `s = 0`. The mean-value bound
  (`bound_of_deriv` in Lean, `bound_of_derive` in Rocq, both in `Diana.Real.Quadrature`) gives
  `|f‴(c+s) − f‴(c−s)| ≤ 2M₄s`, so `|E‴| ≤ (2/3)M₄s²`, and three more applications against the
  boundary functions `(2/9)M₄s³`, `M₄s⁴/18` and `M₄s⁵/90` give the bound at `s = h`. As for the
  trapezoidal rule, the integral is taken of the clamped extension of `f` to ℝ, so f⁗ needs only to
  exist and be bounded on `[x, x + 2h]` (`symmetric_error` is the statement about the midpoint;
  `local_error` substitutes `c = x + h`). For `f = x⁴` the error is `24h⁵/90`, so the constant is
  sharp.
- **A2**: `panel_error` of `Diana.Real.Quadrature` with `p` double panels of width `2h`, A1 on each,
  and `sum_triple`, which regroups the panel rules into the weights `1, 4, 2, …, 2, 4, 1`; then
  `p·M₄h⁵/90 = (b − a)·h⁴·M₄/180` because `2p·h = b − a`.
- **B1**: as for the trapezoidal rule (TRAPEZOIDAL-B1): `Bplus`, `Bmult` and `Bdiv` return a
  non-finite value for a non-finite operand and on overflow, so `fadd_finite_inv`,
  `fdiv_finite_inv` (`Diana.Float.Sum`) and `fmul_value` peel the evaluation from the outside in,
  and a prefix of either interior sum is the accumulator of the rest of its fold. Proof:
  `finite_result` in `verification/rocq/theory/Float/Simpson.v`.
- **B2**: both interior sums start from an exact `+0`, so `fold_error` with no absolute term gives
  `|ŝₒ − Σ y₂ₖ₊₁| ≤ γₚ₊₁·Σ|y₂ₖ₊₁|` and `|ŝₑ − Σ y₂ₖ| ≤ γₚ·Σ|y₂ₖ|` (additions have relative error at
  most `u` even below the normal range). `4·ŝₒ` and `2·ŝₑ` are exact (`fmul_exact`, via Flocq's
  `mult_bpow_pos_exact_FLT`). Each of the three additions forming `ŝ` raises the `γ` index by one
  (`add_step`), so `|ŝ − S′| ≤ γₚ₊₃·A`. The product with `h` and the division by 3 each add a
  relative error `u` and an absolute error at most `η` (`round_error`), which `scale_div_error`
  collects into `γₚ₊₅·|h|·A/3 + (1 + u)·η/3 + η`. B1 supplies every no-overflow premise. Proof:
  `forward_error`.
- **C1**: the `/*@ ... */` annotations in `src/simpson.c`. With `p = n / 2`, the assertion
  `n == 2 * p + 1` (from `n` odd) gives the bounds `2k + 1 ≤ n − 2` and `2k ≤ n − 3` for the two
  loops, whose invariants are only `0 <= k <= p` and `1 <= k <= p`. As for the trapezoidal rule, the
  value of `*result` is not an ACSL post-condition (see "Why the functional contract is not in
  ACSL" in `spec/trapezoidal.md`); it is the VST theorem C2.
- **C2**: two Clight loops over a read-only `tarray tdouble n` with a pair index `k` in `Int64`.
  `forward_for` carries `sₒ = c_odd ys k` (the fold over the first `k` odd samples) and
  `sₑ = c_even ys k` (the first `k − 1` even interior samples); `pick_succ` appends one sample
  per iteration, and VST reduces the index expressions `2k + 1` and `2k` and the loop tests
  itself. `p = n / 2` comes from `Int64.divu`, and `n = 2p + 1` from `Z.odd n` (`Zmod_odd`) proves
  that the even-`n` test fails. After the loops, `Znth_map` turns the two endpoint reads into
  floats, so the value passed to `diana_fp_finite` is `c_simpson ys h` by computation. As for the
  trapezoidal rule, `data_at` on the array makes `y` a valid pointer, which is why the NULL,
  `n < 3` and even-`n` paths are left to WP (C1). `diana_fp_finite` is re-specified for this AST
  (`body_diana_fp_finite`). Proof: `body_diana_simpson` in
  `verification/rocq/theory/VST/Simpson.v`.

## Model correspondence

- **Layer B** (`verification/rocq/theory/Float/Simpson.v`): `fsimpson y0 yl odd even h` is
  `fdiv (fmul h (fadd (fadd (fadd y0 yl) (fmul four sₒ)) (fmul two sₑ))) three` with
  `sₒ = fold_left fadd odd zero` and `sₑ = fold_left fadd even zero`, the C's operation order for
  `odd = [y₁, y₃, …, yₙ₋₂]` (length `p`) and `even = [y₂, …, yₙ₋₃]` (length `p − 1`); `zero` is
  `+0` and `two`, `three`, `four` are the binary64 constants. `fadd`, `fmul` and `fdiv`
  (`Diana.Float.Sum`) are `Bplus`, `Bmult` and `Bdiv` in `mode_NE`, parameterised by the
  NaN-payload functions so that they instantiate to CompCert's `Float.add`/`Float.mul`/`Float.div`.
  B2 takes `length even ≤ length odd`, which the kernel's lists satisfy.
- **Layer C, VST** (`verification/rocq/theory/VST/Simpson.v`, against the Clight AST
  `verification/clight/simpson_aarch64_macos.v`, CompCert target AArch64 macOS): `c_simpson ys h`
  is the C computation over the array `ys` with CompCert's `Float.add`/`Float.mul`/`Float.div`,
  and `c_simpson_model` identifies it with `fsimpson` at `y0 = Znth 0 ys`, `yl = Znth (n − 1) ys`,
  `odd = pick ys (2j + 1) p` and `even = pick ys (2j + 2) (p − 1)`, after `c_zero_eq`, `c_two_eq`,
  `c_three_eq` and `c_four_eq` show clightgen's literals equal to the model constants.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| SIMPSON-A1 | proved | proved | – |
| SIMPSON-A2 | proved | proved | – |
| SIMPSON-B1 | – | proved | – |
| SIMPSON-B2 | – | proved | – |
| SIMPSON-C1 | – | – | 58/58 goals (Frama-C 33.0, Alt-Ergo 2.6.4), no assumed contract |
| SIMPSON-C2 | – | proved | – |
