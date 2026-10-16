---
method: euler
kernel: src/euler.c
model: >
  euler y f h : ℝ^d with y_out_i = y_i + h·f_i for i = 0, …, d − 1, where f_i is the caller's
  F(t, y)_i. The binary64 model evaluates each component as fl(y_i + fl(h·f_i)), the product and
  the sum each rounded to nearest-even (no fused multiply-add).
hypothesis:
  - "H1: Y′(t) = F(t, Y(t)) on [t₀, T] with componentwise two-sided derivatives, and Y″ exists there with ‖Y″‖ ≤ M₂ in the max norm; continuity of Y″ is not required (Rocq also takes 0 ≤ M₂, which the bound implies for d ≥ 1)"
  - "H2: F is L-Lipschitz in y in the max norm for t ∈ [t₀, T], with L > 0 (an L-Lipschitz F is L′-Lipschitz for every L′ > L, so this loses nothing)"
  - "H3 (float layers): y_i, f_i and h are arbitrary binary64 values supplied by the caller"
theorem:
  - id: EULER-A1
    layer: A
    informal: "local truncation: under H1 on [t, t + h] with h ≥ 0, ‖Y(t + h) − Y(t) − h·F(t, Y(t))‖ ≤ M₂·h²/2"
    lean: Diana.Real.Euler.local_error
    rocq: Diana.Real.Euler.local_error
  - id: EULER-A2
    layer: A
    informal: "global error: under H1 and H2 on [t₀, t₀ + N·h] with h > 0, the iterates y₀ = Y(t₀), yₖ₊₁ = yₖ + h·F(t₀ + k·h, yₖ) satisfy ‖yₖ − Y(t₀ + k·h)‖ ≤ (M₂·h/(2L))·(e^{L·k·h} − 1) for every k ≤ N"
    lean: Diana.Real.Euler.global_error
    rocq: Diana.Real.Euler.global_error
  - id: EULER-B1
    layer: B
    informal: >
      a finite component certifies its evaluation: if the binary64 model fl(y_i + fl(h·f_i)) is
      finite, then y_i, f_i, h and the product fl(h·f_i) are finite; since a finite Bplus or Bmult
      of finite operands is the rounded exact value (fadd_value, fmul_value), neither operation
      overflowed. This is why the kernel checks only each computed component.
    rocq: Diana.Float.Euler.finite_result
  - id: EULER-B2
    layer: B
    informal: >
      step error per component: if the binary64 model r_i = fl(y_i + fl(h·f_i)) is finite, then
      |r_i − (y_i + h·f_i)| ≤ u·|y_i + h·f_i| + (1 + u)·(u·|h·f_i| + η), with u = 2⁻⁵³ and
      η = 2⁻¹⁰⁷⁵ (underflow in the product).
    rocq: Diana.Float.Euler.forward_error
  - id: EULER-C1
    layer: C
    informal: >
      ACSL contract in src/euler.c, Frama-C WP float model with RTE: memory safety (only
      y[0 .. d−1] and f[0 .. d−1] are read, only y_out[0 .. d−1] is written, y_out separate from
      both), no UB, termination of both loops, DIANA_OK only for non-NULL pointers with d ≥ 1,
      and y_out untouched on DIANA_ERR_ARG. No assumed contract; that y_out is finite on DIANA_OK
      is left to VST.
    acsl: src/euler.c
  - id: EULER-C2
    layer: C
    informal: >
      diana_euler_step computes the binary64 model (VST, AArch64 macOS Clight AST): for y and f
      pointing to d ≥ 1 readable doubles and y_out to d writable doubles, the three disjoint, it
      returns DIANA_OK and writes the model values when every component is finite, and returns
      DIANA_ERR_ARG leaving y_out unchanged otherwise. The NULL and d = 0 paths are EULER-C1.
    rocq: Diana.VST.Euler.body_diana_euler_step
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

- **A1**: with `D(s) = F(s, Y(s)) − F(t, Y(t))` and `G(s) = Y(s) − Y(t) − (s − t)·F(t, Y(t))`,
  `G′ = D` and `D′ = Y″`, both zero at `t`. The mean-value bound against `M₂·(s − t)` gives
  `‖D(s)‖ ≤ M₂·(s − t)`, and against `M₂·(s − t)²/2` gives the result at `s = t + h`. Lean applies
  Mathlib's `image_norm_le_of_norm_deriv_right_le_deriv_boundary` in any normed space; Rocq works
  per component (`taylor_first`, two applications of `bound_of_derive` from
  `Diana.Real.Quadrature`) and lifts with `vnorm_le`.
- **A2**: the one-step lemma `one_step_error` of `Diana.Real.OneStep`: the error `eₖ = yₖ − Y(tₖ)`
  satisfies `eₖ₊₁ = eₖ + h·(F(tₖ, yₖ) − F(tₖ, Y(tₖ))) − τₖ` with `τₖ` the local truncation, so
  `‖eₖ₊₁‖ ≤ (1 + hL)·‖eₖ‖ + τ` (`step_bound`), and `gronwall_pow` with `e₀ = 0` gives
  `‖eₖ‖ ≤ τ·((1 + hL)ᵏ − 1)/(hL) ≤ (τ/(hL))·(e^{khL} − 1)` (`pow_le_exp`, from `1 + x ≤ eˣ`).
  A1 supplies `τ = M₂·h²/2` on every subinterval `[tₖ, tₖ + h]`, so `τ/(hL) = M₂·h/(2L)`. The
  lemma takes any increment function, so RK4 reuses it.
- **B1**: `fadd_finite_inv` and `fmul_value` (`Diana.Float.Sum`) peel the component from the
  outside in. Proof: `finite_result` in `verification/rocq/theory/Float/Euler.v`.
- **B2**: the product is `fl(h·f) = h·f·(1 + e₁) + d₁` with `|e₁| ≤ u`, `|d₁| ≤ η`
  (`round_error`), and the sum of two binary64 values has relative error at most `u` even below
  the normal range (`add_error`): `r = (y + m)·(1 + e₂)`. Then
  `r − (y + h·f) = (m − h·f)·(1 + e₂) + e₂·(y + h·f)`. The bound is attained up to rounding: on
  random inputs with subnormal products, the error reaches 99.995 % of it. Proof: `forward_error`.
- **C1**: the `/*@ ... */` annotations in `src/euler.c`. Every early return happens before the
  second loop, and the only write is `y_out[i]` in that loop, so `assigns y_out[0 .. d − 1]` and
  the error post-condition follow from the control flow; the loop invariants are only the index
  bounds.
- **C2**: the first loop carries `forallb is_finite (sublist 0 i L)` for `L = c_euler h ys fs`
  and calls `diana_fp_finite` on each component (`forward_call`); a non-finite component
  returns at once, and `forallb_false` shows the whole list fails the check, so the
  post-condition leaves `y_out` as it was. The second loop writes: its invariant holds
  `y_out = map Vfloat (sublist 0 i L) ++ sublist i d os`, and each store is an `upd_Znth`
  that `list_solve` folds into the next prefix (`Znth_c_euler` names the stored value). The
  first VST proof in Diana that writes an array and calls a function inside a loop.
  Proof: `body_diana_euler_step` in `verification/rocq/theory/VST/Euler.v`.

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

## Model correspondence

- **Layer A** (`verification/lean/Diana/Real/Euler.lean`, `verification/rocq/theory/Real/Euler.v`):
  the iterate is `iterate F t₀ h y₀ k` of `Diana.Real.OneStep` (`euler` in Rocq), the kernel's
  `y_out = y + h·f` with `f = F(t₀ + k·h, y)` evaluated exactly. Lean states both theorems for
  any real normed space `E`, which includes `Fin d → ℝ` with its sup norm; Rocq represents a
  vector as `nat → R` over the indices `i < d` with `vnorm d x = maxᵢ |x i|`
  (`Diana.Real.Vector`), the same norm. The derivatives are componentwise in Rocq and Fréchet in
  Lean, which agree on `Fin d → ℝ`. Rocq takes `0 ≤ M₂` as a hypothesis, since for `d = 0` the
  bound on `Y″` says nothing; Lean derives it from the bound at `t₀`.

- **Layer B** (`verification/rocq/theory/Float/Euler.v`): `fstep h y f = fadd y (fmul h f)` is one
  component in the C's operation order, and `feuler h ys fs` maps it over `combine ys fs`; `fadd`
  and `fmul` are the `Bplus` and `Bmult` of `Diana.Float.Sum`, parameterised by the NaN-payload
  functions so that they instantiate to CompCert's `Float.add`/`Float.mul`. B1 and B2 are per
  component, because the kernel's components are independent; a max-norm form follows by taking
  the maximum over `i`.
- **Layer C, VST** (`verification/rocq/theory/VST/Euler.v`, against the Clight AST
  `verification/clight/euler_aarch64_macos.v`, CompCert target AArch64 macOS): `c_euler h ys fs`
  is the C computation with CompCert's `Float.add`/`Float.mul`, componentwise over the two
  arrays, and `c_euler_model` identifies it with `feuler`. The funspec holds three separate
  `data_at`, so overlapping `y` and `f`, which the C allows because both are only read, is
  outside the theorem; WP (C1) covers it for memory safety.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| EULER-A1 | proved | proved | – |
| EULER-A2 | proved | proved | – |
| EULER-B1 | – | proved | – |
| EULER-B2 | – | proved | – |
| EULER-C1 | – | – | 49/49 goals (Frama-C 33.0, Alt-Ergo 2.6.4), no assumed contract |
| EULER-C2 | – | proved | – |
