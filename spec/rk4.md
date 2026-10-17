---
method: rk4
kernel: src/rk4.c
model: >
  The classical fourth-order Runge–Kutta step, split into four slope evaluations by the caller and
  two kernel functions. rk4_stage y k h s : ℝ^d with y_out_i = y_i + c·k_i, c = h/2 for stage
  s = 2 or 3 and c = h for s = 4: the points Y₂ = y + (h/2)·k₁, Y₃ = y + (h/2)·k₂ and
  Y₄ = y + h·k₃ at which the caller evaluates kₛ = F(t + cₛ·h, Yₛ), with c₂ = c₃ = 1/2 and c₄ = 1.
  rk4_step y k₁ k₂ k₃ k₄ h : ℝ^d with y_out_i = y_i + h·(k₁ᵢ + 2·k₂ᵢ + 2·k₃ᵢ + k₄ᵢ)/6. The binary64
  model evaluates the stage coefficient as c = fl(h/2) (or h) once and each stage component as
  fl(y_i + fl(c·k_i)), and each step component as fl(y_i + fl(fl(h·s_i)/6)) with
  s_i = fl(fl(k₁ᵢ + k₄ᵢ) + 2·fl(k₂ᵢ + k₃ᵢ)), every operation rounded to nearest-even (no fused
  multiply-add; the doubling is exact unless it overflows).
hypothesis:
  - "H3 (float layers): y_i, k_i, k₁ᵢ, …, k₄ᵢ and h are arbitrary binary64 values supplied by the caller"
theorem:
  - id: RK4-C1
    layer: C
    informal: >
      ACSL contracts in src/rk4.c, Frama-C WP float model with RTE: for diana_rk4_stage and
      diana_rk4_step, memory safety (only y[0 .. d−1] and the slope arrays are read, only
      y_out[0 .. d−1] is written, y_out separate from every input), no UB, termination of both
      loops of each, DIANA_OK only for non-NULL pointers with d ≥ 1 (and 2 ≤ stage ≤ 4 for the
      stage), and y_out untouched on DIANA_ERR_ARG. No assumed contract; that y_out is finite on
      DIANA_OK is left to VST.
    acsl: src/rk4.c
---
# rk4

One step of the classical Runge–Kutta method on a caller-owned vector of dimension `d`, in
reverse communication. The kernel never calls `F`; per step the caller evaluates

```
k₁ = F(t, y)
k₂ = F(t + h/2, Y₂),  Y₂ = rk4_stage(y, k₁, h, 2) = y + (h/2)·k₁
k₃ = F(t + h/2, Y₃),  Y₃ = rk4_stage(y, k₂, h, 3) = y + (h/2)·k₂
k₄ = F(t + h,   Y₄),  Y₄ = rk4_stage(y, k₃, h, 4) = y + h·k₃
y_out = rk4_step(y, k₁, k₂, k₃, k₄, h) = y + h·(k₁ + 2·k₂ + 2·k₃ + k₄)/6
```

The stage number is the row of the Butcher tableau whose point the call builds, so the
coefficients `1/2, 1/2, 1` live in the kernel and not in the caller. The stage times
`t + h/2` and `t + h` are the caller's. `y_out` must not overlap `y` or any slope; the inputs
are only read and may overlap each other.

## Operation order

`diana_rk4_stage` computes the coefficient once, `c = 0.5·h` for stages 2 and 3 (exact unless
`|h| < 2⁻¹⁰²¹`, where it may round) and `c = h` for stage 4, then each component as
`fl(y[i] + fl(c·k[i]))`, the Euler step of size `c`. `diana_rk4_step` computes each component as
`s = (k₁[i] + k₄[i]) + 2·(k₂[i] + k₃[i])`, then `fl(y[i] + fl(fl(h·s)/6))`; the symmetric
grouping halves the rounding of the slope sum against summing left to right, and dividing the
product by 6 matches `(h·s)/3` in the Simpson rule. Both functions make two passes, as
`diana_euler_step` does: the first computes every component and checks it with
`diana_fp_finite` without writing, and returns `DIANA_ERR_ARG` at the first non-finite one; the
second recomputes each component, bit for bit the same, and writes it. A NaN or infinite input,
or an overflow in any operation, is an error, since no operation turns an infinity or NaN into a
finite value (the only divisor is the constant 6); underflow is not an error. An overflow of `h·s`
is an error even when `h·s/6` would be finite.

## Proof sketch

- **C1**: the `/*@ ... */` annotations in `src/rk4.c`, as for `src/euler.c` (EULER-C1): every
  early return happens before the second loop, and the only write is `y_out[i]` in that loop, so
  `assigns y_out[0 .. d − 1]` and the error post-condition follow from the control flow; the loop
  invariants are only the index bounds.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| RK4-C1 | – | – | 98/98 goals (Frama-C 33.0, Alt-Ergo 2.6.4), no assumed contract |
