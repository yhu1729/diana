---
id: PROOF-003
title: Trapezoidal rule theorems and their hypotheses
kind: fact
path:
  - spec/trapezoidal.md
  - src/trapezoidal.c
related: [PROOF-007, API-013]
---
The trapezoidal rule is proved through every layer (`spec/trapezoidal.md`); the rounding bound
is relative to the absolute sum `A`, not to the result.

- Layer A, Lean and Rocq, under H1 (`f` has derivative `f′` and `f′` has derivative `f″` at every
  point of `[a, b]`, two-sided, `|f″| ≤ M₂`, no continuity of `f″`): A1 on `[x, x + h]`, `h ≥ 0`,
  `|∫ₓ^{x+h} f − h·(f(x) + f(x + h))/2| ≤ M₂·h³/12`; A2 with H2 (`a ≤ b`, `m ≥ 1` panels,
  `h = (b − a)/m`, `yᵢ = f(a + i·h)` exactly) `|∫ₐᵇ f − T| ≤ (b − a)·h²·M₂/12`.
- Layer B, Rocq and Flocq, for arbitrary binary64 `yᵢ` and `h`: B1 a finite result makes `h`,
  every sample and every partial sum finite, so no operation overflowed (why the kernel checks
  only `r`); B2 if the result `r` is finite and `n·u < 1`,
  `|r − T| ≤ γₙ·|h|·A + (1 + γₙ₋₁)·|h|·η + η`, with `T` the exact rule on the given samples,
  `A = |y₀ + yₙ₋₁|/2 + Σ_{i=1}^{n−2} |yᵢ|`, `γₖ = k·u/(1 − k·u)`, `u = 2⁻⁵³`, `η = 2⁻¹⁰⁷⁵`.
- Layer C: WP (C1, no assumed contract) proves memory safety, that only `y[0 .. n−1]` is read and
  only `*result` written, termination, `DIANA_OK` only for non-NULL arguments with `n ≥ 2` and
  then `*result` finite, and `*result` untouched on `DIANA_ERR_ARG`. VST (C2) proves, for
  `n ≥ 2` readable doubles and a separate writable `*result`, that the kernel returns `DIANA_OK`
  and writes the binary64 model value when it is finite, and `DIANA_ERR_ARG` with `*result`
  unchanged otherwise; C3 is the `diana_fp_finite` copy.
- Limits: B2 says little under cancellation (`|T| ≪ A`); `n·u < 1` holds for every `n < 2⁵³`;
  spacing is uniform. The end-to-end bound that adds A2, B2 and the sample errors is a
  derivation in the "Composition" section of `spec/trapezoidal.md`, not a listed theorem. WP
  states no value beyond finiteness, because an ACSL `(double)` cast disagrees with IEEE
  rounding at the overflow boundary ("Why the functional contract is not in ACSL").
