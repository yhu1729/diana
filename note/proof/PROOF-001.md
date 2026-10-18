---
id: PROOF-001
title: Bisection theorems and the missing explicit step bound
kind: fact
path:
  - spec/bisection.md
  - src/bisection_mid.c
  - src/bisection_init.c
  - src/bisection_step.c
  - src/bisection_result.c
related: [PROOF-007, API-007, API-008, API-024, WP-003]
---
Bisection is proved through every layer (`spec/bisection.md`); what is not proved is an explicit
bound on the binary64 step count.

- Layer A, Lean and Rocq, under H1 (`f` continuous on `[a, b]`) and H2 (`a ≤ b` with
  `f(a)·f(b) < 0`, or `a = b` with `f(a) = 0`): A1 the bracket invariant and
  `bₙ − aₙ ≤ (b − a)/2ⁿ`; A2 a root `x* ∈ [aₙ, bₙ]`, so `|mₙ − x*| ≤ (b − a)/2ⁿ⁺¹`. Both are
  about the real midpoint sequence.
- Layer B, Rocq and Flocq, under H3 (`|a|, |b| ≤ DBL_MAX/2`, every supplied f-value finite,
  `tol ≥ 0`): B1 `fl(0.5·fl(a + b))` is finite and in `[a, b]`; B2 one `fstep` from a state
  satisfying `Bracket` and `Next` keeps finiteness, `a ≤ b`, the magnitude bound and the
  sign condition, and nests the bracket; B3 adjacent endpoints (`succ a = b`) make the midpoint
  an endpoint, the kernel's `DIANA_OK` stop; B4 `n` consecutive `DIANA_CONTINUE` steps satisfy
  `n ≤ lattice`, the number of doubles the bracket spans, so every run terminates.
- Layer C: WP proves the ACSL contracts of `init`, `step` and `result` (C2 to C4), assuming the
  contract of `diana_bisection_mid`, which B1 discharges (WP-003); they cover the `status` field
  (`init` and `step` write it on every exit but an error, and `step` proceeds only from
  `DIANA_CONTINUE`). VST proves `diana_bisection_mid` (C1), `result` for any `status` (C7),
  `init` and `step` against the C-order models `c_init`, `c_step` (C8, C9; `step` on a state
  whose `status` is not `DIANA_CONTINUE` returns `DIANA_ERR_ARG` unchanged), `c_step` equal to
  `fstep` (C10), `c_init` and every continuing `c_step` establishing `Bracket` and `Next` (C11,
  C12), and each copy of the `src/fp.h` helpers in an AST (C5, C6, C13). C8 to C12 put every
  state of an `init`-then-`step` run under B2 to B4.
- Not proved: a numeric step bound. `lattice` can reach about `2¹⁰⁷⁵`; the 2098-step worst case
  behind `max_iter = 2100` is measured and test-pinned, not a theorem (API-024, "What B4 does
  not say" in `spec/bisection.md`). Layer B restates the A1 invariant for its own `fstep`; no
  theorem maps a binary64 run onto the real sequence, and the "within `tol/2` + 1 ulp" remark
  under "Tolerance rationale" is not a listed theorem.
