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
  multiply-add; the doubling is exact unless it overflows). Over the reals the step is
  y_{n+1} = y_n + h·Φ(t_n, y_n) with the increment Φ = (k₁ + 2·k₂ + 2·k₃ + k₄)/6 evaluated exactly
  (incT in both provers), and rk4 F t₀ h y₀ k is its k-th iterate.
hypothesis:
  - "H1: y′ = F(t, y) is treated as the autonomous system z′ = G(z) on z = (t, y) with G(t, y) = (1, F(t, y)), which RK4 respects (RK4-A6). G has derivatives G′, G″, G‴ (Lean: Fréchet, G₂ = D G₁ and G₃ = D G₂ everywhere, as continuous (multi)linear maps; Rocq: componentwise along every curve differentiable in the first D components, with G′(x), G″(x), G‴(x) linear in each vector argument). Only G‴ appears, not a fourth derivative"
  - "H2: the solution satisfies Y′ = G(Y) on [t, t + h], and its fourth derivative E₄(Y(s)), written through G′, G″, G‴ (E₂ = G′G, E₃ = G″(G, G) + G′E₂, E₄ = G‴(G, G, G) + G″(E₂, G) + 2·G″(G, E₂) + G′E₃), satisfies ‖E₄(Y(s)) − E₄(Y(t))‖ ≤ M₅·(s − t) in the max norm for s ∈ [t, t + h]; this holds when ‖Y⁽⁵⁾‖ ≤ M₅"
  - "H3: Φ(s), the increment of one step of size s from Y(t), has the third step-size derivative Φ‴ = d₃ of RK4-A1 with ‖Φ‴(s) − Φ‴(0)‖ ≤ N₄·s for s ∈ [0, h]; this holds when ‖Φ⁗‖ ≤ N₄, and is a hypothesis on the method applied to F rather than on F alone"
  - "H4: F is L-Lipschitz in y in the max norm for t ∈ [t₀, T], with L > 0"
  - "H5 (float layers): y_i, k_i, k₁ᵢ, …, k₄ᵢ and h are arbitrary binary64 values supplied by the caller"
theorem:
  - id: RK4-A1
    layer: A
    informal: >
      step-size derivatives of the increment: under H1, for the autonomous increment
      Φ(s) = inc G y s and every s, the jet components d₁, d₂, d₃ of incJet (explicit sums of G′,
      G″, G‴ along the three stage curves y + (s/2)·k₁(s), y + (s/2)·k₂(s), y + s·k₃(s)) are the
      first, second and third derivatives of Φ in s.
    lean: Diana.Real.RK4.inc_deriv
    rocq: Diana.Real.RK4.inc_deriv
  - id: RK4-A2
    layer: A
    informal: >
      order conditions: under H1, Φ(0) = G(y), Φ′(0) = E₂(y)/2, Φ″(0) = E₃(y)/3 and
      Φ‴(0) = E₄(y)/4, so the Taylor polynomial of y + s·Φ(s) agrees with that of the solution
      through s⁴. Only linearity is used, not the symmetry of G″.
    lean: Diana.Real.RK4.order_conditions
    rocq: Diana.Real.RK4.order_conditions
  - id: RK4-A3
    layer: A
    informal: >
      local truncation of order 4: under H1, H2 and H3 with h ≥ 0,
      ‖Y(t + h) − Y(t) − h·Φ(h)‖ ≤ (M₅/120 + N₄/24)·h⁵ (Rocq also takes 0 ≤ M₅ and 0 ≤ N₄).
    lean: Diana.Real.RK4.local_error
    rocq: Diana.Real.RK4.local_error
  - id: RK4-A4
    layer: A
    informal: >
      stability: if F(s, ·) is L-Lipschitz for s ∈ [t, t + h] with h ≥ 0 and L ≥ 0, then
      ‖Φ(t, y) − Φ(t, z)‖ ≤ L·(1 + hL/2 + (hL)²/6 + (hL)³/24)·‖y − z‖.
    lean: Diana.Real.RK4.lipschitz
    rocq: Diana.Real.RK4.lipschitz
  - id: RK4-A5
    layer: A
    informal: >
      convergence from consistency: under H4 on [t₀, t₀ + N·h] with h > 0, if one step from the
      solution at every grid point is within τ ≥ 0 of the solution, the iterates
      y_{k+1} = y_k + h·Φ(t₀ + k·h, y_k), y₀ = Y(t₀), satisfy
      ‖y_k − Y(t₀ + k·h)‖ ≤ τ/(hL)·(e^{L·k·h} − 1) for every k ≤ N, the Euler form with L itself.
    lean: Diana.Real.RK4.global_error
    rocq: Diana.Real.RK4.global_error
  - id: RK4-A6
    layer: A
    informal: >
      autonomization: the increment of the autonomous field G(t, y) = (1, F(t, y)) at (t, y) is
      (1, Φ(t, y)), so RK4 on the augmented state is RK4 on y with the stage times t + h/2 and
      t + h (Lean on ℝ × E; Rocq on vectors with time at index d, for F whose first d components
      depend only on the first d components of y at the stage times, which H4 implies).
    lean: Diana.Real.RK4.inc_autonomous
    rocq: Diana.Real.RK4.inc_autonomous
  - id: RK4-A7
    layer: A
    informal: >
      global error of order 4: under H1, H4, Y′ = F(t, Y) on [t₀, t₀ + N·h] and H2, H3 at every
      grid point for G = (1, F) and Ŷ(s) = (s, Y(s)), with h > 0, the iterates satisfy
      ‖y_k − Y(t₀ + k·h)‖ ≤ ((M₅/120 + N₄/24)·h⁴/L)·(e^{L·k·h} − 1) for every k ≤ N.
    lean: Diana.Real.RK4.convergence
    rocq: Diana.Real.RK4.convergence
  - id: RK4-B1
    layer: B
    informal: >
      a finite stage component certifies its evaluation: if the binary64 model
      fl(y_i + fl(c·k_i)) is finite, with c = h for stage 4 and c = fl(h/2) otherwise, then h,
      y_i, k_i, c and the product fl(c·k_i) are finite, so no operation overflowed.
    rocq: Diana.Float.RK4.stage_finite
  - id: RK4-B2
    layer: B
    informal: >
      stage coefficient: if the computed coefficient c̃ is finite, then |c̃ − c| ≤ η for the exact
      c = h/2 (stages 2 and 3) or c = h (stage 4), and c̃ = c exactly when |h| ≥ 2⁻¹⁰²¹ or the stage
      is 4; η = 2⁻¹⁰⁷⁵.
    rocq: Diana.Float.RK4.coef_error
  - id: RK4-B3
    layer: B
    informal: >
      stage error per component: if r_i = fl(y_i + fl(c̃·k_i)) is finite, then
      |r_i − (y_i + c·k_i)| ≤ u·|y_i + c·k_i| + (1 + u)·(u·|c·k_i| + η) + (1 + u)²·|c̃ − c|·|k_i|,
      with c the exact coefficient of RK4-B2 (so the last term is 0 for |h| ≥ 2⁻¹⁰²¹),
      u = 2⁻⁵³ and η = 2⁻¹⁰⁷⁵.
    rocq: Diana.Float.RK4.stage_error
  - id: RK4-B4
    layer: B
    informal: >
      a finite step component certifies its evaluation: if the binary64 model
      fl(y_i + fl(fl(h·s_i)/6)) with s_i = fl(fl(k₁ᵢ + k₄ᵢ) + 2·fl(k₂ᵢ + k₃ᵢ)) is finite, then h,
      y_i, the four slopes and every intermediate (both pair sums, the doubling, s_i, the product
      and the quotient) are finite, so no operation overflowed. This is why the kernel checks only
      each computed component.
    rocq: Diana.Float.RK4.step_finite
  - id: RK4-B5
    layer: B
    informal: >
      step error per component: if r_i is finite, then
      |r_i − (y_i + h·S_i/6)| ≤ u·|y_i + h·S_i/6| + (1 + u)·(γ₄·|h|·A_i/6 + (1 + u)·η/6 + η), with
      S_i = k₁ᵢ + 2·k₂ᵢ + 2·k₃ᵢ + k₄ᵢ the exact slope sum, A_i = |k₁ᵢ + k₄ᵢ| + 2·|k₂ᵢ + k₃ᵢ|,
      γ₄ = 4u/(1 − 4u), u = 2⁻⁵³ and η = 2⁻¹⁰⁷⁵ (underflow in the product and in the division
      by 6).
    rocq: Diana.Float.RK4.step_error
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
  - id: RK4-C2
    layer: C
    informal: >
      diana_rk4_stage computes the binary64 model (VST, AArch64 macOS Clight AST): for y and k
      pointing to d ≥ 1 readable doubles, y_out to d writable doubles, the three disjoint, and
      2 ≤ stage ≤ 4, it returns DIANA_OK and writes the model values when every component is
      finite, and returns DIANA_ERR_ARG leaving y_out unchanged otherwise. The NULL, d = 0 and
      out-of-range stage paths are RK4-C1.
    rocq: Diana.VST.RK4.body_diana_rk4_stage
  - id: RK4-C3
    layer: C
    informal: >
      diana_rk4_step computes the binary64 model (VST, AArch64 macOS Clight AST): for y and the
      four slopes pointing to d ≥ 1 readable doubles and y_out to d writable doubles, the six
      disjoint, it returns DIANA_OK and writes the model values when every component is finite,
      and returns DIANA_ERR_ARG leaving y_out unchanged otherwise. The NULL and d = 0 paths are
      RK4-C1.
    rocq: Diana.VST.RK4.body_diana_rk4_step
  - id: RK4-C4
    layer: C
    informal: >
      the C-order stage model c_stage (CompCert's Float.add and Float.mul, the coefficient
      Float.mul 0.5 h or h) is the Flocq model frk4_stage, so RK4-B1 to B3 apply to every
      component diana_rk4_stage writes.
    rocq: Diana.VST.RK4.c_stage_model
  - id: RK4-C5
    layer: C
    informal: >
      the C-order step model c_rk4 (CompCert's Float.add, Float.mul and Float.div with the
      constants 2 and 6) is the Flocq model frk4_step, so RK4-B4 and B5 apply to every component
      diana_rk4_step writes.
    rocq: Diana.VST.RK4.c_rk4_model
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
is an error even when `h·s/6` would be finite. The opt-in one-pass variants without the check,
`diana_rk4_stage_unchecked` and `diana_rk4_step_unchecked`, have their own spec,
`spec/rk4_unchecked.md`.

## Proof sketch

- **A1**: a jet is a value with its first three derivatives. `Jet.app` (Rocq `japp`) maps the jet
  of a curve γ to that of G∘γ by the chain rule: (G∘γ)‴ = G‴(γ′, γ′, γ′) + G″(γ″, γ′) +
  2·G″(γ′, γ″) + G′γ‴, where G″(a, b) is the derivative of G′ in direction a applied to b.
  `Jet.lin` maps the jet of K to that of s ↦ y + (c·s)·K(s), whose j-th derivative is
  j·c·K⁽ʲ⁻¹⁾ + c·s·K⁽ʲ⁾. Chaining `app ∘ lin` three times gives the stage slopes k₂, k₃, k₄
  (`chain_app`, `chain_lin`, `chain_inc`); `incJet_v` (Rocq `incjet_v`) identifies the value with
  the increment.
- **A2**: at s = 0 every `lin` term with the factor c·s vanishes, the jets of the stages reduce to
  linear combinations of G, G′G, G″(G, G), G‴(G, G, G), G″(G′G, G), G″(G, G′G), G′G″(G, G) and
  G′G′G′G, and the weights 1, 2, 2, 1 over 6 give E₂/2, E₃/3 and E₄/4. The terms G″(γ″, γ′) and
  2·G″(γ′, γ″) appear in the same proportion in Φ‴ and in Y⁗, so G″ need not be symmetric. Lean
  closes each identity with `module`; Rocq computes the jets at 0 stage by stage (`jet2_0`,
  `jet3_0`, `jet4_0`) with the linearity hypotheses.
- **A3**: `taylor_bound` (`Diana.Real.Taylor`, both provers) bounds the remainder of an order-n
  Taylor polynomial by M·(x − a)ⁿ⁺¹/(n + 1)! when the n-th derivative is M-Lipschitz from a; it is
  proved by induction with the mean-value bound used for Euler. Applied to Y with n = 4
  (derivatives G∘Y, E₂∘Y, E₃∘Y, E₄∘Y, H2) and to Φ with n = 3 (A1, H3), it gives
  ‖Y(t + h) − P_Y‖ ≤ M₅h⁵/120 and ‖Φ(h) − P_Φ‖ ≤ N₄h⁴/24, and A2 makes
  P_Y − Y(t) − h·P_Φ vanish. Splitting the hypotheses at the top derivative avoids a fourth
  derivative of G, which a fifth derivative of y + s·Φ(s) would need.
- **A4**: stage by stage, ‖Δk₁‖ ≤ L·e, ‖Δk₂‖ ≤ L·(e + (h/2)·‖Δk₁‖), ‖Δk₃‖ ≤ L·(e + (h/2)·‖Δk₂‖),
  ‖Δk₄‖ ≤ L·(e + h·‖Δk₃‖) with e = ‖y − z‖; the weighted sum is the stated polynomial.
- **A5**: `one_step_pow` (factored out of `one_step_error` in `Diana.Real.OneStep`) gives
  ‖e_k‖ ≤ τ·((1 + hK)ᵏ − 1)/(hK) for the Lipschitz constant K of A4. Then 1 + hK = Σᵢ₌₀⁴ (hL)ⁱ/i!
  ≤ e^{hL} (Mathlib `Real.sum_le_exp_of_nonneg`; Rocq `exp_ge_poly`, by monotonicity) and
  hK ≥ hL, so the bound becomes τ/(hL)·(e^{Lkh} − 1).
- **A6**: the stage points of the augmented system have time components t, t + h/2, t + h/2,
  t + h and the y components of the non-autonomous stages; Lean is direct algebra on ℝ × E, and
  Rocq uses that F's first d components ignore the time slot of the augmented vector (`local`,
  derived from H4 by `lipschitz_local`).
- **A7**: A3 for G = (1, F) and Ŷ(s) = (s, Y(s)) on each grid interval bounds the y component of
  the augmented local error by τ = (M₅/120 + N₄/24)·h⁵ (A6), and A5 turns τ into the global
  bound.
- **B1, B4**: `fadd_finite_inv`, `fmul_value` and `fdiv_finite_inv` (`Diana.Float.Sum`) peel a
  finite result from the outside in; the stage is `fstep` of `Diana.Float.Euler` with the
  computed coefficient as its step, so B1 reuses EULER-B1. Proofs: `stage_finite`,
  `step_finite` in `verification/rocq/theory/Float/RK4.v`.
- **B2**: for stage 4 the coefficient is `h` itself. Otherwise it is `fl(h/2)`, within `η` of
  `h/2` by `half_error` of `Diana.Float.Trapezoidal`, and exact when `|h| ≥ 2⁻¹⁰²¹`: then
  `mag(h) ≥ −1020` and Flocq's `mult_bpow_exact_FLT` puts `h·2⁻¹` in the format (`half_exact`).
  Proof: `coef_error`.
- **B3**: the product is `fl(c̃·k) = c̃·k·(1 + e₁) + d₁` and the sum `(y + m)·(1 + e₂)`, as in
  EULER-B2; writing `c̃·k = c·k + (c̃ − c)·k` adds `(1 + u)·|c̃ − c|·|k|` to the product error,
  and the factor `1 + e₂` makes it `(1 + u)²`. Proof: `stage_error`.
- **B5**: each pair sum has relative error at most `u ≤ γ₁` (`add_error`); the doubling is exact
  (`fmul_exact`); `add_step` with `k = 1` gives `|s − S| ≤ γ₂·A` for the exact `S` and
  `|S| ≤ A`. The product with `h` and the division by 6 add two more relative errors and an
  absolute `η` each (`scale_div6_error`, the Simpson argument with 6 for 3):
  `|q − h·S/6| ≤ γ₄·|h|·A/6 + (1 + u)·η/6 + η`. The final sum is `(y + q)·(1 + e)`, which gives
  the bound as in EULER-B2. On 200 000 random components (half with normal, half with subnormal
  slopes) the error reaches 99.93 % of the bound. Proof: `step_error`.
- **C1**: the `/*@ ... */` annotations in `src/rk4.c`, as for `src/euler.c` (EULER-C1): every
  early return happens before the second loop, and the only write is `y_out[i]` in that loop, so
  `assigns y_out[0 .. d − 1]` and the error post-condition follow from the control flow; the loop
  invariants are only the index bounds.
- **C2**: the Euler proof (EULER-C2) with the coefficient for the step. Five range checks
  precede the loops (`stage < 2` and `stage > 4` are false under `2 ≤ stage ≤ 4`); the branch
  on `stage == 4` sets `c` to `c_coef stage h`, and the two loops then carry exactly the
  invariants of `body_diana_euler_step` for `L = c_euler c ys ks`, reusing its list lemmas
  (`Znth_c_euler`, `forallb_sublist_succ`, `forallb_false`). Proof: `body_diana_rk4_stage` in
  `verification/rocq/theory/VST/RK4.v`.
- **C3**: the same two loops over `L = c_rk4 h ys k₁s k₂s k₃s k₄s`, with seven reads and
  assignments per component in place of three; `Znth_c_rk4` names the stored value. Proof:
  `body_diana_rk4_step`.
- **C4, C5**: the constants `0.5`, `2` and `6` of the Clight AST (`Float.of_bits`) equal the
  Flocq constants by computation (`vm_compute` on `B2FF`), after which the models agree
  structurally (`c_euler_model` for the stage). Proofs: `c_stage_model`, `c_rk4_model`.

## Model correspondence

- **Layer A** (`verification/lean/Diana/Real/RK4.lean`, `verification/rocq/theory/Real/RK4.v`):
  the iterate is `rk4 F t₀ h y₀ k`, `iterate` of `Diana.Real.OneStep` with the increment
  `incT F t y h` = (k₁ + 2·k₂ + 2·k₃ + k₄)/6, k₁ = F(t, y), k₂ = F(t + h/2, y + (h/2)·k₁),
  k₃ = F(t + h/2, y + (h/2)·k₂), k₄ = F(t + h, y + h·k₃), evaluated exactly: the kernel's step with
  the caller's slopes. Lean states the theorems in any real normed space E (A6 and A7 on ℝ × E with
  the max norm); Rocq uses `nat → R` over the first D components with `vnorm`, and puts time at
  index d of the augmented vector (`aug`, `auto`). The derivative hypotheses differ in form: Lean
  takes Fréchet derivatives (`HasFDerivAt` for G, G₁, G₂); Rocq takes the chain rule along curves
  for G, G₁, G₂ and linearity of G₁, G₂, G₃ in each vector argument, the consequences of Fréchet
  differentiability that the proof uses. `linear_instance` checks that these Rocq hypotheses hold
  for the linear field F(t, y) = a·y, so they are not contradictory.
- **Layer B** (`verification/rocq/theory/Float/RK4.v`): `coef s h` is `h` for `s = 4` and
  `fmul half h` otherwise, with `half` the binary64 constant `0.5` of `Diana.Float.Trapezoidal`;
  `fstage s h y k` is `Diana.Float.Euler.fstep` with step `coef s h`, and `frk4_stage` maps it
  over the components (`feuler`). `fstep h y k₁ k₂ k₃ k₄ = fadd y (fdiv (fmul h (fslope …)) six)`
  with `fslope k₁ k₂ k₃ k₄ = fadd (fadd k₁ k₄) (fmul two (fadd k₂ k₃))` is one step component in
  the C's operation order, and `frk4_step` maps it over five lists. `fadd`, `fmul` and `fdiv` are
  the `Bplus`, `Bmult` and `Bdiv` of `Diana.Float.Sum`, parameterised by the NaN-payload
  functions. B1 to B5 are per component; a max-norm form follows by taking the maximum over `i`.
- **Layer C, VST** (`verification/rocq/theory/VST/RK4.v`, against the Clight AST
  `verification/clight/rk4_aarch64_macos.v`, CompCert target AArch64 macOS): `c_coef stage h`
  and `c_stage = c_euler (c_coef stage h)` are the stage in CompCert's `Float` operations, and
  `c_step`/`c_rk4` the step; C4 and C5 identify them with `frk4_stage` and `frk4_step`. Each
  funspec holds separate `data_at` for every array, so overlapping inputs, which the C allows
  because they are only read, are outside the theorems; WP (C1) covers them for memory safety.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| RK4-A1 | proved | proved | – |
| RK4-A2 | proved | proved | – |
| RK4-A3 | proved | proved | – |
| RK4-A4 | proved | proved | – |
| RK4-A5 | proved | proved | – |
| RK4-A6 | proved | proved | – |
| RK4-A7 | proved | proved | – |
| RK4-B1 | – | proved | – |
| RK4-B2 | – | proved | – |
| RK4-B3 | – | proved | – |
| RK4-B4 | – | proved | – |
| RK4-B5 | – | proved | – |
| RK4-C1 | – | – | 98/98 goals (Frama-C 33.0, Alt-Ergo 2.6.4), no assumed contract |
| RK4-C2 | – | proved | – |
| RK4-C3 | – | proved | – |
| RK4-C4 | – | proved | – |
| RK4-C5 | – | proved | – |
