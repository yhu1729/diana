---
id: PROOF-005
title: Euler step theorems, checked and unchecked
kind: fact
path:
  - spec/euler.md
  - spec/euler_unchecked.md
  - src/euler_step.c
  - src/euler_step_unchecked.c
related: [PROOF-007, API-015, API-018]
---
The checked Euler step is proved through every layer (`spec/euler.md`); the unchecked step has
layer-B finiteness and layer-C theorems only (`spec/euler_unchecked.md`). No theorem carries the
per-step rounding error through the global bound.

- Layer A, Lean and Rocq, in the max norm. H1: `Y′ = F(t, Y)` on `[t₀, T]` with two-sided
  componentwise derivatives and `Y″` existing with `‖Y″‖ ≤ M₂` (no continuity; Rocq also takes
  `0 ≤ M₂`). H2: `F` is `L`-Lipschitz in `y`, `L > 0`. A1 (H1, `h ≥ 0`)
  `‖Y(t + h) − Y(t) − h·F(t, Y(t))‖ ≤ M₂·h²/2`. A2 (H1, H2 on `[t₀, t₀ + N·h]`, `h > 0`) the
  exact iterates from `y₀ = Y(t₀)` satisfy `‖yₖ − Y(t₀ + k·h)‖ ≤ (M₂·h/(2L))·(e^{L·k·h} − 1)`,
  `k ≤ N`.
- Layer B, per component, arbitrary binary64 inputs: B1 a finite `fl(y_i + fl(h·f_i))` makes
  `y_i`, `f_i`, `h` and the product finite; B2 then
  `|r_i − (y_i + h·f_i)| ≤ u·|y_i + h·f_i| + (1 + u)·(u·|h·f_i| + η)`, `u = 2⁻⁵³`, `η = 2⁻¹⁰⁷⁵`.
- Layer C: WP (C1, no assumed contract) proves memory safety, separation of `y_out`, termination,
  `DIANA_OK` only for non-NULL pointers with `d ≥ 1`, `DIANA_ERR_OVERFLOW` only with `h`, `y` and
  `f` finite, and `y_out` untouched on both errors; not finiteness on `DIANA_OK`. VST (C2), for
  disjoint `y`, `f`, `y_out` with `d ≥ 1`: `DIANA_OK` with the model values when all are finite,
  else `y_out` unchanged and `DIANA_ERR_OVERFLOW` when `h`, `y` and `f` are finite,
  `DIANA_ERR_ARG` when not (`euler_status`). C3 is the `diana_fp_finite` copy.
- Unchecked: EULER-UNCHECKED-B1 a component is finite exactly when `h`, `y_i`, `f_i` are
  finite, `|∘(h·f_i)| < 2¹⁰²⁴` and `|∘(y_i + ∘(h·f_i))| < 2¹⁰²⁴` (`∘` rounding to nearest-even);
  EULER-UNCHECKED-C1 (WP) `DIANA_OK` exactly for valid arguments, `y_out` untouched on
  `DIANA_ERR_ARG`, no value statement; EULER-UNCHECKED-C2 (VST) it always writes the C-order
  model `c_euler` of the checked step, so EULER-B1 and B2 hold for each finite component.
- Not proved: a global bound for the binary64 iteration, and the VST theorems for overlapping
  `y` and `f`, which the C allows.
