---
method: axpy_unchecked
kernel: src/axpy_unchecked.c
model: >
  The update of spec/axpy.md without the finiteness check: yᵢ ← a·xᵢ + yᵢ in place, and the same
  binary64 model fl(yᵢ + fl(a·xᵢ)) per component, the product and the sum each rounded to
  nearest-even (no fused multiply-add). Every component is written, finite or not.
hypothesis:
  - "H1 (float layer): a, xᵢ and yᵢ are arbitrary binary64 values supplied by the caller"
theorem:
  - id: AXPY-UNCHECKED-B1
    layer: B
    informal: >
      a finite component is exactly a successful evaluation: the binary64 model
      fl(yᵢ + fl(a·xᵢ)) is finite if and only if a, xᵢ and yᵢ are finite and neither operation
      overflows, |∘(a·xᵢ)| < 2¹⁰²⁴ and |∘(yᵢ + ∘(a·xᵢ))| < 2¹⁰²⁴, with ∘ the rounding to
      nearest-even over the reals (EULER-UNCHECKED-B1 with a as the step size). So a NaN or
      infinite input or an overflow always leaves a non-finite component, and a finiteness check
      of y afterwards catches every such case.
    rocq: Diana.Float.AxpyUnchecked.finite_iff
  - id: AXPY-UNCHECKED-C1
    layer: C
    informal: >
      ACSL contract in src/axpy_unchecked.c, Frama-C WP float model with RTE: memory safety (only
      x[0 .. n−1] and y[0 .. n−1] are read, only y[0 .. n−1] is written, y separate from x), no
      UB, termination of the loop, DIANA_OK exactly for non-NULL pointers, and y untouched on
      DIANA_ERR_ARG. No assumed contract and no statement about the written values.
    acsl: src/axpy_unchecked.c
  - id: AXPY-UNCHECKED-C2
    layer: C
    informal: >
      diana_axpy_unchecked computes the binary64 model unconditionally (VST, AArch64 macOS Clight
      AST): for x pointing to n ≥ 1 readable doubles and y to n writable doubles, the two
      disjoint, it returns DIANA_OK and writes c_euler a ys xs over y, finite or not. That list is
      the C-order model c_axpy a xs ys of AXPY-C2 (c_axpy_euler), equal to the Flocq model faxpy,
      so AXPY-B1 and B2 hold for every finite component and AXPY-UNCHECKED-B1 for every
      component. The NULL and n = 0 paths are AXPY-UNCHECKED-C1.
    rocq: Diana.VST.AxpyUnchecked.body_diana_axpy_unchecked
---
# axpy_unchecked

`diana_axpy_unchecked` is the opt-in update `y ← a·x + y` without the finiteness check of
`diana_axpy` (`spec/axpy.md`). It takes the same arguments with the same aliasing rule: `x` is
only read and must not overlap `y`.

## Operation order

The kernel rejects a NULL `x` or `y` before writing anything, then makes one pass that computes
each component as `fl(y[i] + fl(a·x[i]))`, in the operation order of the checked kernel
(`-ffp-contract=off`), writes it over `y[i]`, NaN and ±∞ included, and returns `DIANA_OK`. It
calls nothing, not even `diana_fp_finite`, so it does not test `a` either: `n = 0` with a NaN
`a` is `DIANA_OK`. Where the checked kernel succeeds, the two write the same bits (both write
`c_axpy`, AXPY-C2 and AXPY-UNCHECKED-C2), and the checked kernel fails exactly when `a` is not
finite or some component written here is not finite. Which NaN a component holds when both
operands of an operation are NaN is the IEEE choice of the target, which the VST model fixes to
CompCert's `Float.add`/`Float.mul`; the compiler comparison found no difference on AArch64 macOS.

## Proof sketch

- **B1**: `fupdate a x y = fstep a y x` (`fupdate_fstep` of `Diana.Float.Axpy`), so
  EULER-UNCHECKED-B1 (`finite_iff` of `Diana.Float.EulerUnchecked`) applies with `h := a`,
  `y := y`, `f := x`; the conjunction is reordered. Proof: `finite_iff` in
  `verification/rocq/theory/Float/AxpyUnchecked.v`.
- **C1**: the `/*@ ... */` annotations in `src/axpy_unchecked.c`. The only early return is the
  NULL check, before the loop writes anything, so the status equivalence and the error
  post-condition follow from the control flow; the loop invariant is the index bound.
- **C2**: the NULL check (false under the precondition), then the write loop of AXPY-C2 with the
  same invariant, `y = map Vfloat (sublist 0 i L ++ sublist i n ys)` for
  `L = c_euler a ys xs`, the load of `y[i]` as `Znth i ys` and the store moved into the second
  part of the list. The loop ends with `y = map Vfloat L` and the function returns 0. Proof:
  `body_diana_axpy_unchecked` in `verification/rocq/theory/VST/AxpyUnchecked.v`.

## Model correspondence

- **Layer B** (`verification/rocq/theory/Float/AxpyUnchecked.v`): `fupdate` of
  `Diana.Float.Axpy`, the model of AXPY-B1 and B2.
- **Layer C, VST** (`verification/rocq/theory/VST/AxpyUnchecked.v`, against the Clight AST
  `verification/clight/axpy_unchecked_aarch64_macos.v`, CompCert target AArch64 macOS):
  `c_euler a ys xs` of the AST-free `Diana.VST.Euler`, since `VST/Axpy.v` imports the checked
  kernel's AST and cannot be imported beside this one; `c_axpy_euler` in `VST/Axpy.v` equates it
  with `c_axpy a xs ys`. The funspec holds two separate `data_at`, the second writable, so it
  assumes `x` and `y` disjoint, as the ACSL precondition requires.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| AXPY-UNCHECKED-B1 | – | proved | – |
| AXPY-UNCHECKED-C1 | – | – | 19/19 goals (Frama-C 32.1, Alt-Ergo 2.6.4), no assumed contract |
| AXPY-UNCHECKED-C2 | – | proved | – |
