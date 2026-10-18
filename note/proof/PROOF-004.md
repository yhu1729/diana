---
id: PROOF-004
title: Simpson rule theorems and their hypotheses
kind: fact
path:
  - spec/simpson.md
  - src/simpson.c
related: [PROOF-003, PROOF-007, API-014]
---
The Simpson rule is proved through every layer (`spec/simpson.md`), on the pattern of the
trapezoidal rule (PROOF-003).

- Layer A, Lean and Rocq, under H1 (`f`, `f′`, `f″`, `f‴` have two-sided derivatives on `[a, b]`
  and `|f⁗| ≤ M₄`, no continuity of `f⁗`): A1 on `[x, x + 2h]`, `h ≥ 0`,
  `|∫ₓ^{x+2h} f − (h/3)·(f(x) + 4·f(x + h) + f(x + 2h))| ≤ M₄·h⁵/90`, sharp for `f = x⁴`; A2 with
  H2 (`a ≤ b`, `m = 2p` panels, `p ≥ 1`, `h = (b − a)/m`, exact samples)
  `|∫ₐᵇ f − S| ≤ (b − a)·h⁴·M₄/180`.
- Layer B, Rocq and Flocq, for arbitrary binary64 samples and `h`: B1 a finite result makes `h`,
  every sample and every partial sum of both interior sums finite, so no operation overflowed;
  B2 if the result `r` is finite, the even list is no longer than the odd one (true of the
  kernel's) and `(p + 5)·u < 1`, `|r − h·S′/3| ≤ γₚ₊₅·|h|·A/3 + (1 + u)·η/3 + η`, with
  `S′ = y₀ + yₙ₋₁ + 4·Σ y₂ₖ₊₁ + 2·Σ y₂ₖ`, `A = |y₀ + yₙ₋₁| + 4·Σ|y₂ₖ₊₁| + 2·Σ|y₂ₖ|`,
  `p = (n − 1)/2`, `γₖ = k·u/(1 − k·u)`, `u = 2⁻⁵³`, `η = 2⁻¹⁰⁷⁵`.
- Layer C: WP (C1, no assumed contract) proves memory safety, termination of both loops,
  `DIANA_OK` only for non-NULL arguments with an odd `n ≥ 3` and then `*result` finite,
  `DIANA_ERR_OVERFLOW` only with `h` and every sample finite, and `*result` untouched on both
  errors. VST (C2) proves, for an odd `n ≥ 3` of readable doubles and a separate writable
  `*result`, `DIANA_OK` with the binary64 model value when it is finite, and otherwise, `*result`
  unchanged, `DIANA_ERR_OVERFLOW` when `h` and every sample are finite and `DIANA_ERR_ARG` when
  not (`simpson_status`); C3 is the `diana_fp_finite` copy.
- Limits as for the trapezoidal rule: B2 is relative to `A`, not to the result; no listed theorem
  composes A2 with B2; WP states no value beyond finiteness.
