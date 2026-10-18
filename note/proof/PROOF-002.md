---
id: PROOF-002
title: Newton theorems; no convergence or termination in binary64
kind: fact
path:
  - spec/newton.md
  - src/newton_init.c
  - src/newton_step.c
  - src/newton_result.c
related: [PROOF-007, API-010, API-011]
---
Newton's method is proved through every layer for one step and for exact-arithmetic convergence
near a simple root (`spec/newton.md`); nothing bounds the binary64 run except `max_iter`.

- Hypotheses: H1 `f` and `f′` have two-sided derivatives `f′`, `f″` on the interval `I`, with
  `|f″| ≤ M` (no continuity of `f″`); H2 `|f′| ≥ m > 0` on `I` and `f(r) = 0` for some
  `r ∈ I`; H3 `I = [r − δ, r + δ]`, `δ ≥ 0`, `|x₀ − r| ≤ δ`, `q = M·δ/(2m) < 1`.
- Layer A, Lean and Rocq: A1 (H1, H2, `x, r ∈ I`) `|x − f(x)/f′(x) − r| ≤ (M/(2m))·(x − r)²`;
  A2 (H1 to H3) every iterate stays in `I` and `|xₙ − r| ≤ δ·q^(2ⁿ − 1)`. The real model has no
  zero or stagnation stop.
- Layer B, Rocq and Flocq (H4: `x`, `f(x)`, `f′(x)`, `tol` binary64, `tol ≥ 0`): B1 a finite
  `fl(x − fl(f/f′))` makes `x`, `f` and the correction finite, so nothing overflowed; B2 if it is
  finite and `f′ ≠ 0`, `|x′ − (x − f/f′)| ≤ u·|x − f/f′| + (1 + u)·(u·|f/f′| + η)`; B3 for finite
  `x`, `dx` with `fl(x − dx)` finite, `fl(x − dx) = x` implies `|dx| ≤ ulp(x)/2`, the meaning
  of the stagnation stop. `u = 2⁻⁵³`, `η = 2⁻¹⁰⁷⁵`.
- Layer C: WP (C1 to C3, no assumed contract) proves memory safety, the invariant (`x`, `dx`,
  `tol` finite, `tol ≥ 0`), `iter + 1`, the condition behind each status (`DIANA_OK` only with
  `|dx| ≤ tol` or `x` unchanged, `DIANA_ERR_SINGULAR` only with `dfx = 0` and `fx ≠ 0`,
  `DIANA_ERR_OVERFLOW` only with `fx`, `dfx` finite and non-zero, ...) and an unchanged state on
  `DIANA_ERR_ARG`, `DIANA_ERR_SINGULAR` and `DIANA_ERR_OVERFLOW`. VST proves `result` (C4),
  `init` and `step` against `c_init`, `c_step` (C5, C6), the stored `x` and `dx` equal to `fstep`
  and `fdiv` so B2 and B3 apply to them (C7), and the `src/fp.h` copies (C8 to C10).
- Not proved: termination or convergence from an arbitrary `x₀`, or in binary64 at all; near a
  simple root the iterates commonly two-cycle (API-011). Multiple roots (`m = 0`) are outside
  H2. Errors in the caller's `f(x)`, `f′(x)` are the caller's: B2 covers the kernel's two
  operations on the values given.
