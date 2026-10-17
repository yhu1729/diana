---
method: rk4_unchecked
kernel: [src/rk4_stage_unchecked.c, src/rk4_step_unchecked.c]
model: >
  The RK4 stage and step of spec/rk4.md without the finiteness check, with the same binary64
  models: the stage coefficient c̃ = h for stage 4 and fl(h/2) for stages 2 and 3, each stage
  component fl(y_i + fl(c̃·k_i)), and each step component fl(y_i + fl(fl(h·s_i)/6)) with
  s_i = fl(fl(k₁ᵢ + k₄ᵢ) + 2·fl(k₂ᵢ + k₃ᵢ)), every operation rounded to nearest-even (no fused
  multiply-add). Every component is written, finite or not.
hypothesis:
  - "H1 (float layer): y_i, k_i, k₁ᵢ, …, k₄ᵢ and h are arbitrary binary64 values supplied by the caller"
theorem:
  - id: RK4-UNCHECKED-B1
    layer: B
    informal: >
      a finite stage component is exactly a successful evaluation: fl(y_i + fl(c̃·k_i)) is finite
      if and only if h, y_i and k_i are finite and neither operation overflows,
      |∘(c̃·k_i)| < 2¹⁰²⁴ and |∘(y_i + ∘(c̃·k_i))| < 2¹⁰²⁴, with ∘ the rounding to nearest-even
      over the reals; the coefficient fl(h/2) is finite whenever h is.
    rocq: Diana.Float.RK4Unchecked.stage_finite_iff
  - id: RK4-UNCHECKED-B2
    layer: B
    informal: >
      a finite step component is exactly a successful evaluation: fl(y_i + fl(fl(h·s_i)/6)) is
      finite if and only if h, y_i and the four slopes are finite and none of the seven
      operations overflows: with a = ∘(k₁ᵢ + k₄ᵢ), b = ∘(k₂ᵢ + k₃ᵢ), t = ∘(2·b), s = ∘(a + t),
      p = ∘(h·s) and q = ∘(p/6), each of |a|, |b|, |t|, |s|, |p|, |q| and |∘(y_i + q)| is below
      2¹⁰²⁴.
    rocq: Diana.Float.RK4Unchecked.step_finite_iff
  - id: RK4-UNCHECKED-C1
    layer: C
    informal: >
      ACSL contract in src/rk4_stage_unchecked.c, Frama-C WP float model with RTE: memory safety
      (only y[0 .. d−1] and k[0 .. d−1] are read, only y_out[0 .. d−1] is written, y_out separate
      from both), no UB, termination of the loop, DIANA_OK exactly for non-NULL pointers with
      d ≥ 1 and 2 ≤ stage ≤ 4, and y_out untouched on DIANA_ERR_ARG. No assumed contract and no
      statement about the written values.
    acsl: src/rk4_stage_unchecked.c
  - id: RK4-UNCHECKED-C2
    layer: C
    informal: >
      ACSL contract in src/rk4_step_unchecked.c, Frama-C WP float model with RTE: memory safety
      (only y[0 .. d−1] and the four slope arrays are read, only y_out[0 .. d−1] is written,
      y_out separate from every input), no UB, termination of the loop, DIANA_OK exactly for
      non-NULL pointers with d ≥ 1, and y_out untouched on DIANA_ERR_ARG. No assumed contract and
      no statement about the written values.
    acsl: src/rk4_step_unchecked.c
  - id: RK4-UNCHECKED-C3
    layer: C
    informal: >
      diana_rk4_stage_unchecked computes the binary64 model unconditionally (VST, AArch64 macOS
      Clight AST): for y and k pointing to d ≥ 1 readable doubles, y_out to d writable doubles,
      the three disjoint, and 2 ≤ stage ≤ 4, it returns DIANA_OK and writes c_stage stage h ys ks,
      finite or not. c_stage is the C-order model of RK4-C3, equal to the Flocq model frk4_stage
      (RK4-C5), so RK4-B1 to B3 hold for every finite component and RK4-UNCHECKED-B1 for every
      component. The NULL, d = 0 and out-of-range stage paths are RK4-UNCHECKED-C1.
    rocq: Diana.VST.RK4StageUnchecked.body_diana_rk4_stage_unchecked
  - id: RK4-UNCHECKED-C4
    layer: C
    informal: >
      diana_rk4_step_unchecked computes the binary64 model unconditionally (VST, AArch64 macOS
      Clight AST): for y and the four slopes pointing to d ≥ 1 readable doubles and y_out to d
      writable doubles, the six disjoint, it returns DIANA_OK and writes
      c_rk4 h ys k₁s k₂s k₃s k₄s, finite or not. c_rk4 is the C-order model of RK4-C4, equal to
      the Flocq model frk4_step (RK4-C6), so RK4-B4 and B5 hold for every finite component and
      RK4-UNCHECKED-B2 for every component. The NULL and d = 0 paths are RK4-UNCHECKED-C2.
    rocq: Diana.VST.RK4StepUnchecked.body_diana_rk4_step_unchecked
---
# rk4_unchecked

`diana_rk4_stage_unchecked` and `diana_rk4_step_unchecked` are the opt-in RK4 stage and step
without the finiteness check of `diana_rk4_stage` and `diana_rk4_step` (`spec/rk4.md`). They take
the same arguments with the same aliasing rules: `y_out` must not overlap `y` or any slope, and
the inputs, which are only read, may overlap each other. Each lives in its own source file,
`src/rk4_stage_unchecked.c` and `src/rk4_step_unchecked.c`.

## Operation order

Each function rejects its argument errors before writing anything: a NULL pointer, `d = 0` and,
for the stage, a stage outside 2 to 4. The stage then computes the coefficient once, `c = h` for
stage 4 and `c = 0.5·h` otherwise, and the step needs none. Then one pass computes each component
in the operation order of the checked function, `fl(y[i] + fl(c·k[i]))` or
`fl(y[i] + fl(fl(h·s)/6))` with `s = (k₁[i] + k₄[i]) + 2·(k₂[i] + k₃[i])`, writes it, NaN and ±∞
included, and returns `DIANA_OK`. Neither function calls anything. Where the checked function
succeeds, the two write the same bits (both write `c_stage` or `c_rk4`: RK4-C3 and
RK4-UNCHECKED-C3, RK4-C4 and RK4-UNCHECKED-C4), and the checked function fails exactly when some
component written here is not finite. Which NaN a component holds when both operands of an
operation are NaN is the IEEE choice of the target, which the VST models fix to CompCert's
`Float` operations; the compiler comparison found no difference on AArch64 macOS.

## Proof sketch

- **B1**: the stage is `fstep` of `Diana.Float.Euler` with the computed coefficient as its
  step, so EULER-UNCHECKED-B1 applies; `coef_finite` adds that the coefficient is finite
  exactly when `h` is: `fl(h/2)` of a finite `h` stays below `|h| < 2¹⁰²⁴`
  (`abs_round_le_generic`, `abs_B2R_lt_emax`). Proof: `stage_finite_iff` in
  `verification/rocq/theory/Float/RK4Unchecked.v`.
- **B2**: from a finite component, RK4-B4 (`step_finite`) makes the inputs and every
  intermediate finite; `fadd_finite_iff`, `fmul_finite_iff` and `fdiv_finite_iff`
  (`Diana.Float.Sum`) turn each finite operation into its range condition, and `fadd_value`,
  `fmul_value` and `fdiv_value` rewrite each intermediate as its rounded exact value, with the
  constants 2 and 6 by `B2R_two` and `B2R_six`. Conversely the range conditions make the seven
  operations finite one after the other, inside out. Proof: `step_finite_iff`.
- **C1, C2**: the `/*@ ... */` annotations in `src/rk4_stage_unchecked.c` and
  `src/rk4_step_unchecked.c`. The only early return is the argument check, before the loop
  writes anything, so the status equivalence and the error post-condition follow from the
  control flow; the loop invariant is the index bound.
- **C3**: six argument checks (three NULL pointers, `d = 0`, `stage < 2` and `stage > 4`, each
  false under the precondition), the branch on `stage == 4` that sets `c` to `c_coef stage h`,
  then the write loop of RK4-C3 for `L = c_stage stage h ys ks`, with the invariant
  `y_out = map Vfloat (sublist 0 i L) ++ sublist i d os` and three statements per component;
  `Znth_c_euler` names the stored value. Proof: `body_diana_rk4_stage_unchecked` in
  `verification/rocq/theory/VST/RK4StageUnchecked.v`.
- **C4**: seven argument checks (six NULL pointers and `d = 0`), then the write loop of RK4-C4 for
  `L = c_rk4 h ys k₁s k₂s k₃s k₄s` with seven statements per component; `Znth_c_rk4` names the
  stored value. Proof: `body_diana_rk4_step_unchecked` in
  `verification/rocq/theory/VST/RK4StepUnchecked.v`.

## Model correspondence

- **Layer B** (`verification/rocq/theory/Float/RK4Unchecked.v`): `fstage` and `fstep` of
  `Diana.Float.RK4`, the models of RK4-B1 to B5.
- **Layer C, VST** (`verification/rocq/theory/VST/RK4StageUnchecked.v` and `RK4StepUnchecked.v`,
  against the Clight ASTs `verification/clight/rk4_stage_unchecked_aarch64_macos.v` and
  `rk4_step_unchecked_aarch64_macos.v`, CompCert target AArch64 macOS): `c_coef`, `c_stage` and
  `c_rk4` of `Diana.VST.RK4`, which RK4-C5 and C6 identify with `frk4_stage` and `frk4_step`.
  Each funspec holds separate `data_at` for every array, so overlapping inputs, which the C
  allows because they are only read, are outside the theorems; WP (C1, C2) covers them for
  memory safety.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| RK4-UNCHECKED-B1 | – | proved | – |
| RK4-UNCHECKED-B2 | – | proved | – |
| RK4-UNCHECKED-C1 | – | – | 21/21 goals (Frama-C 32.1, Alt-Ergo 2.6.4), no assumed contract |
| RK4-UNCHECKED-C2 | – | – | 22/22 goals (Frama-C 32.1, Alt-Ergo 2.6.4), no assumed contract |
| RK4-UNCHECKED-C3 | – | proved | – |
| RK4-UNCHECKED-C4 | – | proved | – |
