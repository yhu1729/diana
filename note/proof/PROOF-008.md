---
id: PROOF-008
title: RK4 rounding and C-code theorems, checked and unchecked
kind: fact
path:
  - spec/rk4.md
  - spec/rk4_unchecked.md
  - src/rk4_stage.c
  - src/rk4_step.c
  - src/rk4_stage_unchecked.c
  - src/rk4_step_unchecked.c
related: [PROOF-006, PROOF-005, PROOF-007, API-016, API-018]
---
Flocq bounds each RK4 stage and step component, and VST proves the C writes exactly those
binary64 values (`spec/rk4.md`, `spec/rk4_unchecked.md`). Bounds are per component, for
arbitrary binary64 inputs, with `u = 2⁻⁵³`, `η = 2⁻¹⁰⁷⁵`.

- B1: a finite stage component `fl(y_i + fl(c̃·k_i))` (`c̃ = h` for stage 4, `fl(h/2)`
  otherwise) makes `h`, `y_i`, `k_i`, `c̃` and the product finite.
- B2: a finite `c̃` is within `η` of the exact `c` (`h/2` or `h`), and equals it when
  `|h| ≥ 2⁻¹⁰²¹` or for stage 4.
- B3: a finite `r_i` satisfies `|r_i − (y_i + c·k_i)| ≤ u·|y_i + c·k_i| + (1 + u)·(u·|c·k_i| + η)
  + (1 + u)²·|c̃ − c|·|k_i|`; the last term vanishes for stage 4 and for `|h| ≥ 2⁻¹⁰²¹`.
- B4: a finite step component makes `h`, `y_i`, the slopes and every intermediate finite.
- B5: `|r_i − (y_i + h·S_i/6)| ≤ u·|y_i + h·S_i/6| + (1 + u)·(γ₄·|h|·A_i/6 + (1 + u)·η/6 + η)`,
  `S_i = k₁ᵢ + 2·k₂ᵢ + 2·k₃ᵢ + k₄ᵢ`, `A_i = |k₁ᵢ + k₄ᵢ| + 2·|k₂ᵢ + k₃ᵢ|`, `γ₄ = 4u/(1 − 4u)`.
- C1, C2 (WP, no assumed contract): memory safety, separation of `y_out`, termination,
  `DIANA_OK` only for valid arguments, `DIANA_ERR_OVERFLOW` only with `h` and every input finite,
  `y_out` untouched on both errors; not finiteness. C3, C4 (VST), for disjoint arrays, `d ≥ 1`
  and `2 ≤ stage ≤ 4`: `DIANA_OK` with the C-order model values when all are finite, else
  `y_out` unchanged and `DIANA_ERR_OVERFLOW` when `h` and every input are finite, `DIANA_ERR_ARG`
  when not (`stage_status`, `rk4_status`). C5, C6: those
  models (`c_stage`, `c_rk4`) are the Flocq `frk4_stage`, `frk4_step`, so B1 to B5 apply to the
  written values. C7, C8: the `diana_fp_finite` copies.
- Unchecked, no layer A of its own: RK4-UNCHECKED-B1, B2 a component is finite exactly when the
  inputs are finite and no operation overflows (two for the stage, seven for the step);
  RK4-UNCHECKED-C1, C2 (WP) `DIANA_OK` exactly for valid arguments, no value statement;
  RK4-UNCHECKED-C3, C4 (VST) the same models written unconditionally, so B1 to B5 hold for
  every finite component.
- Not proved: a global bound with rounding (no theorem combines B3, B5 with RK4-A7), the error
  of the caller's slopes, and the VST theorems for overlapping inputs.
