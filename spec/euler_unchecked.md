---
method: euler_unchecked
kernel: src/euler_step_unchecked.c
model: >
  The explicit Euler step of spec/euler.md without the finiteness check: euler y f h : ℝ^d with
  y_out_i = y_i + h·f_i, and the same binary64 model fl(y_i + fl(h·f_i)) per component, the product
  and the sum each rounded to nearest-even (no fused multiply-add). Every component is written,
  finite or not.
hypothesis:
  - "H1 (float layer): y_i, f_i and h are arbitrary binary64 values supplied by the caller"
theorem:
  - id: EULER-UNCHECKED-B1
    layer: B
    informal: >
      a finite component is exactly a successful evaluation: the binary64 model
      fl(y_i + fl(h·f_i)) is finite if and only if h, y_i and f_i are finite and neither operation
      overflows, |∘(h·f_i)| < 2¹⁰²⁴ and |∘(y_i + ∘(h·f_i))| < 2¹⁰²⁴, with ∘ the rounding to
      nearest-even over the reals. So a NaN or infinite input or an overflow always leaves a
      non-finite component, and a finiteness check of the written components afterwards catches
      every such case.
    rocq: Diana.Float.EulerUnchecked.finite_iff
  - id: EULER-UNCHECKED-C1
    layer: C
    informal: >
      ACSL contract in src/euler_step_unchecked.c, Frama-C WP float model with RTE: memory safety
      (only y[0 .. d−1] and f[0 .. d−1] are read, only y_out[0 .. d−1] is written, y_out separate
      from both), no UB, termination of the loop, DIANA_OK exactly for non-NULL pointers with
      d ≥ 1, and y_out untouched on DIANA_ERR_ARG. No assumed contract and no statement about the
      written values.
    acsl: src/euler_step_unchecked.c
  - id: EULER-UNCHECKED-C2
    layer: C
    informal: >
      diana_euler_step_unchecked computes the binary64 model unconditionally (VST, AArch64 macOS
      Clight AST): for y and f pointing to d ≥ 1 readable doubles and y_out to d writable
      doubles, the three disjoint, it returns DIANA_OK and writes c_euler h ys fs, finite or not.
      c_euler is the C-order model of EULER-C2, equal to the Flocq model feuler, so EULER-B1 and
      B2 hold for every finite component and EULER-UNCHECKED-B1 for every component. The NULL
      and d = 0 paths are EULER-UNCHECKED-C1.
    rocq: Diana.VST.EulerStepUnchecked.body_diana_euler_step_unchecked
---
# euler_unchecked

`diana_euler_step_unchecked` is the opt-in explicit Euler step without the finiteness check of
`diana_euler_step` (`spec/euler.md`). It takes the same arguments with the same aliasing rules:
`y_out` must not overlap `y` or `f`, which are only read.

## Operation order

The step rejects a NULL `y`, `f` or `y_out` and `d = 0` before writing anything, then makes one
pass that computes each component as `fl(y[i] + fl(h·f[i]))`, in the operation order of the
checked step (`-ffp-contract=off`), writes it, NaN and ±∞ included, and returns `DIANA_OK`. It
calls nothing, not even `diana_fp_finite`. Where the checked step succeeds, the two write the same
bits (both write `c_euler`, EULER-C2 and EULER-UNCHECKED-C2), and the checked step fails exactly
when some component written here is not finite. Which NaN a component holds when both operands
of an operation are NaN is the IEEE choice of the target, which the VST model fixes to
CompCert's `Float.add`/`Float.mul`; the compiler comparison found no difference on AArch64 macOS.

## Proof sketch

- **B1**: `fadd_finite_iff` and `fmul_finite_iff` (`Diana.Float.Sum`) state, for finite
  operands, that the result of `Bplus` or `Bmult` is finite exactly when its correctly rounded
  exact value is below `2¹⁰²⁴` in magnitude: `Bplus_correct` and `Bmult_correct` give the
  rounded value in that case and `binary_overflow`, an infinity, otherwise. From a finite
  component, EULER-B1 (`finite_result`) makes the inputs and the product finite, `fmul_value`
  names the product's value, and the two lemmas give both range conditions; conversely the
  range conditions make the product finite with the rounded value, and then the sum. Proof:
  `finite_iff` in `verification/rocq/theory/Float/EulerUnchecked.v`.
- **C1**: the `/*@ ... */` annotations in `src/euler_step_unchecked.c`. The only early return is
  the argument check, before the loop writes anything, so the status equivalence and the error
  post-condition follow from the control flow; the loop invariant is the index bound.
- **C2**: three argument checks, then the write loop of EULER-C2 with the same invariant,
  `y_out = map Vfloat (sublist 0 i L) ++ sublist i d os` for `L = c_euler h ys fs`; each store
  is an `upd_Znth` that `list_solve` folds into the next prefix (`Znth_c_euler` of
  `Diana.VST.Euler` names the stored value). The loop ends with `y_out = map Vfloat L` and the
  function returns 0. Proof: `body_diana_euler_step_unchecked` in
  `verification/rocq/theory/VST/EulerStepUnchecked.v`.

## Model correspondence

- **Layer B** (`verification/rocq/theory/Float/EulerUnchecked.v`): `fstep` of
  `Diana.Float.Euler`, the model of EULER-B1 and B2.
- **Layer C, VST** (`verification/rocq/theory/VST/EulerStepUnchecked.v`, against the Clight AST
  `verification/clight/euler_step_unchecked_aarch64_macos.v`, CompCert target AArch64 macOS):
  `c_euler` of `Diana.VST.Euler`, which `c_euler_model` identifies with `feuler`. The funspec
  holds three separate `data_at`, so overlapping `y` and `f`, which the C allows because both are
  only read, is outside the theorem; WP (C1) covers it for memory safety.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| EULER-UNCHECKED-B1 | – | proved | – |
| EULER-UNCHECKED-C1 | – | – | 19/19 goals (Frama-C 33.0, Alt-Ergo 2.6.4), no assumed contract |
| EULER-UNCHECKED-C2 | – | proved | – |
