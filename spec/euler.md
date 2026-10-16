---
method: euler
kernel: src/euler.c
model: >
  euler y f h : ℝ^d with y_out_i = y_i + h·f_i for i = 0, …, d − 1, where f_i is the caller's
  F(t, y)_i. The binary64 model evaluates each component as fl(y_i + fl(h·f_i)), the product and
  the sum each rounded to nearest-even (no fused multiply-add).
hypothesis:
  - "H1: Y′(t) = F(t, Y(t)) on [t₀, T] with componentwise two-sided derivatives, and Y″ exists there with ‖Y″‖ ≤ M₂ in the max norm; continuity of Y″ is not required"
  - "H2: F is L-Lipschitz in y in the max norm for t ∈ [t₀, T], with L > 0 (an L-Lipschitz F is L′-Lipschitz for every L′ > L, so this loses nothing)"
  - "H3 (float layers): y_i, f_i and h are arbitrary binary64 values supplied by the caller"
theorem:
  - id: EULER-C1
    layer: C
    informal: >
      ACSL contract in src/euler.c, Frama-C WP float model with RTE: memory safety (only
      y[0 .. d−1] and f[0 .. d−1] are read, only y_out[0 .. d−1] is written, y_out separate from
      both), no UB, termination of both loops, DIANA_OK only for non-NULL pointers with d ≥ 1,
      and y_out untouched on DIANA_ERR_ARG. No assumed contract; that y_out is finite on DIANA_OK
      is left to VST.
    acsl: src/euler.c
---
# euler

One explicit Euler step on a caller-owned vector of dimension `d`. The kernel never calls `F`:
the caller evaluates `f = F(t, y)` and passes it with `y` and the step `h`, and the kernel
writes `y_out = y + h·f`. `y_out` must not overlap `y` or `f`; `y` and `f` are only read. An
integration is a loop of such steps in the caller.

## Operation order

Each component is `fl(y[i] + fl(h·f[i]))`; the build disables contraction
(`-ffp-contract=off`), so the product is rounded before the sum. The kernel makes two passes:
the first computes every component and checks it with `diana_fp_finite` without writing, and
returns `DIANA_ERR_ARG` at the first non-finite one; the second recomputes each component, bit
for bit the same, and writes it. So `y_out` is untouched on every error without a scratch
buffer, as the other kernels leave their outputs untouched. A NaN or infinite `y[i]`, `f[i]` or
`h`, or an overflow in either operation, is an error; underflow is not.

## Proof sketch

- **C1**: the `/*@ ... */` annotations in `src/euler.c`. Every early return happens before the
  second loop, and the only write is `y_out[i]` in that loop, so `assigns y_out[0 .. d − 1]` and
  the error post-condition follow from the control flow; the loop invariants are only the index
  bounds.

## Why finiteness on success is not in ACSL

The second pass writes values it does not check again; they are finite because the first pass
checked the same computation. WP's float model represents the C expression `y[i] + h * f[i]` with
the IEEE operations `add_f64` and `mul_f64`, while an ACSL term can only express it through casts,
`(double)(y[i] + (double)(h * f[i]))`, which WP translates to `to_f64` of a real sum. The two agree
only through the range axioms of the float theory, so a loop invariant cannot carry "this component
was finite" from the first pass to the second (the same gap as "Why the functional contract is not
in ACSL" in `spec/trapezoidal.md`). Asserting it would need an assumed helper contract, as
`bisection_mid` has. Instead the VST theorem C2, which relates the C to the Flocq model, gives
finiteness and the exact values together.

## Planned theorems

A theorem is listed in the front matter together with its proof, because the strict spec gate fails
on a listed theorem that is not proved:

- **A1** (Lean, Rocq): local truncation, `‖Y(t + h) − Y(t) − h·F(t, Y(t))‖ ≤ M₂·h²/2` under H1.
- **A2** (Lean, Rocq): global error of `yₖ₊₁ = yₖ + h·F(tₖ, yₖ)`, `y₀ = Y(t₀)`, `tₖ = t₀ + kh ≤ T`:
  `‖yₖ − Y(tₖ)‖ ≤ (M₂·h/(2L))·(e^{L(tₖ−t₀)} − 1)` under H1 and H2, from a discrete Grönwall
  lemma for one-step methods shared with RK4. Rocq vectors are `nat → R` with the max norm; Lean
  states the theorems for any normed space.
- **B1** (Flocq): a finite component certifies that `y_i`, `f_i` and `h` are finite and that no
  operation overflowed.
- **B2** (Flocq): per component, `|r_i − (y_i + h·f_i)| ≤ u·|y_i + h·f_i| + (1 + u)·(u·|h·f_i| + η)`.
- **C2** (VST): `diana_euler_step` writes the Flocq model values and returns `DIANA_OK` exactly
  when all of them are finite, leaving `y_out` unchanged otherwise.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| EULER-C1 | – | – | 49/49 goals (Frama-C 33.0, Alt-Ergo 2.6.4), no assumed contract |
