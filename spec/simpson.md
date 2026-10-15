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
  - id: SIMPSON-C1
    layer: C
    informal: >
      ACSL contract in src/simpson.c, Frama-C WP float model with RTE: memory safety (only
      y[0 .. n−1] is read, only *result is written), no UB, termination of both loops, DIANA_OK
      only for non-NULL y and result with n ≥ 3 odd and then *result finite, and *result
      untouched on DIANA_ERR_ARG. No assumed contract.
    acsl: src/simpson.c
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

- **C1**: the `/*@ ... */` annotations in `src/simpson.c`. With `p = n / 2`, the assertion
  `n == 2 * p + 1` (from `n` odd) gives the bounds `2k + 1 ≤ n − 2` and `2k ≤ n − 3` for the two
  loops, whose invariants are only `0 <= k <= p` and `1 <= k <= p`. As for the trapezoidal rule, the
  value of `*result` is not an ACSL post-condition (see "Why the functional contract is not in
  ACSL" in `spec/trapezoidal.md`); it will be a VST theorem on the Flocq model.

## Planned theorems

A theorem is listed in the front matter together with its proof, because the strict spec gate fails
on a listed theorem that is not proved:

- **A1** (Lean, Rocq): on `[x, x + 2h]` with `h ≥ 0`,
  `|∫ₓ^{x+2h} f − (h/3)·(f(x) + 4·f(x + h) + f(x + 2h))| ≤ M₄·h⁵/90`, by four applications of the
  mean-value bound of `Diana.Real.Quadrature` to the error about the midpoint and its first three
  derivatives, all zero at the midpoint.
- **A2** (Lean, Rocq): under H1 and H2, `|∫ₐᵇ f − S| ≤ (b − a)·h⁴·M₄/180`, by `panel_error` with
  `p` double panels of width `2h`.
- **B1** (Flocq): a finite result certifies that every sample, `h` and every intermediate is finite.
- **B2** (Flocq): forward error relative to `A = |y₀ + yₙ₋₁| + 4·Σ|y₂ₖ₊₁| + 2·Σ|y₂ₖ|`, from the
  shared summation bound of `Diana.Float.Sum`.
- **C2** (VST): `diana_simpson` computes the Flocq model value, against
  `verification/clight/simpson_aarch64_macos.v`.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| SIMPSON-C1 | – | – | 58/58 goals (Frama-C 33.0, Alt-Ergo 2.6.4), no assumed contract |
