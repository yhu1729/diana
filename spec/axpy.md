---
method: axpy
kernel: src/axpy.c
model: >
  axpy a x y : ℝⁿ with yᵢ ← a·xᵢ + yᵢ for i = 0, …, n − 1, in place. The binary64 model evaluates
  each component as fl(yᵢ + fl(a·xᵢ)), the product and the sum each rounded to nearest-even (no
  fused multiply-add): the Euler step of spec/euler.md with a as the step size, y as the state and
  x as the slope, whose Flocq model and lemmas it reuses.
hypothesis:
  - "H1: x and y are lists of reals of equal length (the exact update is defined on the shorter of the two)"
  - "H2 (float layers): a, xᵢ and yᵢ are arbitrary binary64 values supplied by the caller"
theorem:
  - id: AXPY-A1
    layer: A
    informal: "norm bound: ‖a·x + y‖ ≤ |a|·‖x‖ + ‖y‖ for each of the 1-, 2- and maximum norms of spec/norm.md, x and y of equal length"
    lean: Diana.Real.Axpy.bound
    rocq: Diana.Real.Axpy.bound
  - id: AXPY-A2
    layer: A
    informal: "composition: two updates along the same x add their coefficients, axpy a x (axpy b x y) = axpy (a + b) x y"
    lean: Diana.Real.Axpy.compose
    rocq: Diana.Real.Axpy.compose
  - id: AXPY-A3
    layer: A
    informal: "inverse: axpy 0 x y = y, so the update by −a undoes the update by a, axpy (−a) x (axpy a x y) = y, x and y of equal length"
    lean: Diana.Real.Axpy.inverse
    rocq: Diana.Real.Axpy.inverse
  - id: AXPY-B1
    layer: B
    informal: >
      a finite component certifies its evaluation: if the binary64 model fl(yᵢ + fl(a·xᵢ)) is
      finite, then a, xᵢ, yᵢ and the product fl(a·xᵢ) are finite, so neither operation
      overflowed (EULER-B1 with a as the step size). This is why the kernel checks only each
      computed component, after a.
    rocq: Diana.Float.Axpy.finite_result
  - id: AXPY-B2
    layer: B
    informal: >
      error per component: if the binary64 model rᵢ = fl(yᵢ + fl(a·xᵢ)) is finite, then
      |rᵢ − (a·xᵢ + yᵢ)| ≤ u·|a·xᵢ + yᵢ| + (1 + u)·(u·|a·xᵢ| + η), with u = 2⁻⁵³ and η = 2⁻¹⁰⁷⁵
      (underflow in the product); EULER-B2 with a as the step size.
    rocq: Diana.Float.Axpy.forward_error
  - id: AXPY-C1
    layer: C
    informal: >
      ACSL contract in src/axpy.c, Frama-C WP float model with RTE: memory safety (only
      x[0 .. n−1] and y[0 .. n−1] are read, only y[0 .. n−1] is written, y separate from x), no
      UB, termination of the three loops, a status in {DIANA_OK, DIANA_ERR_ARG,
      DIANA_ERR_OVERFLOW}; DIANA_OK and DIANA_ERR_OVERFLOW only for non-NULL pointers and a
      finite a; DIANA_ERR_OVERFLOW only with every x[j] and y[j] finite; DIANA_ERR_ARG only for a
      NULL pointer, a non-finite a or a non-finite x[j] or y[j]; and y untouched on both errors.
      No assumed contract; that y is finite on DIANA_OK is left to VST.
    acsl: src/axpy.c
  - id: AXPY-C2
    layer: C
    informal: >
      diana_axpy computes the binary64 model (VST, AArch64 macOS Clight AST): for x pointing to
      n ≥ 1 readable doubles and y to n writable doubles, the two disjoint, it returns
      axpy_status a xs ys: DIANA_ERR_ARG with y unchanged when a is not finite; else DIANA_OK,
      writing the model values over y, when every component is finite; otherwise, leaving y
      unchanged, DIANA_ERR_OVERFLOW when every x[j] and y[j] is finite and DIANA_ERR_ARG when
      not. The NULL and n = 0 paths are AXPY-C1.
    rocq: Diana.VST.Axpy.body_diana_axpy
  - id: AXPY-C3
    layer: C
    informal: >
      the copy of diana_fp_finite in the Clight AST of axpy implements its IEEE semantics, as
      BISECTION-C5 for the copy in bisection_init (VST, AArch64 macOS Clight AST).
    rocq: Diana.VST.Axpy.body_diana_fp_finite
---
# axpy

The update `y ← a·x + y` of a caller-owned vector of `n` doubles by a multiple of another, in
place: `y[i] = y[i] + a·x[i]` for `i < n`. `x` is only read and must not overlap `y`. The
out-of-place form is `diana_euler_step(y, x, n, a, y_out)`, which computes the same bits; this
kernel is the one that writes over `y`.

## Operation order

The C writes `y[i] + a * x[i]`, the same operand order as the Euler step `y[i] + h * f[i]`, so
that the binary64 model is the Euler one with `a` for `h` and `x` for `f`; the sum is commutative
in IEEE arithmetic, so `a·x[i] + y[i]` would give the same bits. The build disables contraction
(`-ffp-contract=off`), so the product is rounded before the sum. After the NULL checks the kernel
tests `a` with `diana_fp_finite` (`DIANA_ERR_ARG`), also for `n = 0`, so that `DIANA_OK` always
means a finite `a`. Then it makes two passes: the first computes every component and checks it
without writing, and stops at the first non-finite one; the second recomputes each component, bit
for bit the same, and writes it over `y[i]`. Each `y[i]` is read before it is written and `x` is
separate from `y`, so the second pass reads what the first read. Only after a failure does the
kernel test `x[j]` and `y[j]` for every `j`: a NaN or infinite one is `DIANA_ERR_ARG`, and an
overflow in either operation on finite inputs `DIANA_ERR_OVERFLOW`; underflow is not an error.
`n = 0` with non-NULL pointers and a finite `a` is `DIANA_OK` and touches nothing. The opt-in
one-pass update without the check, `diana_axpy_unchecked`, has its own spec,
`spec/axpy_unchecked.md`.

## Proof sketch

- **A1**: `axpy a x y = add (map (a·) x) y`, so the triangle inequality NORM-A4 on
  `map (a·) x` and `y` and the homogeneity NORM-A5 give the bound for each norm.
- **A2**: by induction on `x` and `y` together: `a·p + (b·p + q) = (a + b)·p + q`.
- **A3**: `axpy 0 x y = y` by the same induction (`0·p + q = q`, which needs equal lengths,
  since the shorter list bounds the result), and `axpy (−a) x (axpy a x y) = axpy (−a + a) x y`
  by A2.
- **B1**, **B2**: `fupdate a x y = fstep a y x` by definition, so EULER-B1 and EULER-B2 apply
  with `h := a`, `y := y`, `f := x`; B2 commutes the real sum. Proofs: `finite_result` and
  `forward_error` in `verification/rocq/theory/Float/Axpy.v`.
- **C1**: the `/*@ ... */` annotations in `src/axpy.c`, those of `src/euler_step.c` with the
  write over `y`: every early return happens before the second loop, and the only write is
  `y[i]` in that loop, so `assigns y[0 .. n − 1]` and the untouched `y` follow from the control
  flow; the input loop inside the first pass carries `\is_finite(x[p]) && \is_finite(y[p])` for
  `p < j`, which gives the `DIANA_ERR_OVERFLOW` post-condition at its exit and, at each return
  inside it, the witness of the `DIANA_ERR_ARG` post-condition.
- **C2**: `c_update a x y = c_step a y x` and `c_axpy a xs ys = c_euler a ys xs`, so the prefix
  and finiteness lemmas of `VST/Euler.v` apply. The proof follows `body_diana_euler_step`:
  the call on `a` first, then the first loop with `forallb is_finite (sublist 0 i L)` for
  `L = c_axpy a xs ys` and the input loop on failure. The second loop writes over the array it
  reads: its invariant holds `y = map Vfloat (sublist 0 i L ++ sublist i n ys)`, a float list
  under one `map Vfloat`, so the load of `y[i]` is `Znth i ys` (`app_Znth2`, `Znth_sublist`) and
  the store `upd_Znth i` is moved under the `map` (`upd_Znth_map`) and into the second part
  (`upd_Znth_app2`, `sublist_split`, `sublist_len_1`, `upd_Znth0`) to give the next prefix.
  Proof: `body_diana_axpy` in `verification/rocq/theory/VST/Axpy.v`.

## Why finiteness on success is not in ACSL

As for the Euler step (`spec/euler.md`): WP's float model represents the C expression with
`add_f64` and `mul_f64`, an ACSL term can only express it through casts, and the two agree only
through the range axioms, so a loop invariant cannot carry "this component was finite" from the
first pass to the second. VST's C2 gives finiteness and the exact values together.

## Model correspondence

- **Layer A** (`verification/lean/Diana/Real/Axpy.lean`, `verification/rocq/theory/Real/Axpy.v`):
  vectors are lists of reals, as for the norms; `axpy a x y` is `add (map (Rmult a) x) y` with
  the entrywise `add` of `Diana.Real.Norm` in Rocq and `List.zipWith (· + ·) (x.map (a * ·)) y`
  in Lean, both as long as the shorter list. The theorems are stated against the norms of
  `spec/norm.md`.
- **Layer B** (`verification/rocq/theory/Float/Axpy.v`): `fupdate a x y = fadd y (fmul a x)`,
  one component in the C's operation order and the `fstep a y x` of `Diana.Float.Euler`;
  `faxpy a xs ys` maps it over `combine xs ys`. `fadd` and `fmul` are the `Bplus` and `Bmult` of
  `Diana.Float.Sum`, parameterised by the NaN-payload functions so that they instantiate to
  CompCert's `Float.add`/`Float.mul`.
- **Layer C, VST** (`verification/rocq/theory/VST/Axpy.v`, against the Clight AST
  `verification/clight/axpy_aarch64_macos.v`, CompCert target AArch64 macOS): `c_axpy a xs ys`,
  with `c_update a x y = c_step a y x` of `VST/Euler.v`, is the C computation with CompCert's
  `Float.add`/`Float.mul`, and `c_axpy_model` identifies it with `faxpy`. The funspec holds two
  separate `data_at`, the second writable, so it assumes `x` and `y` disjoint, which the ACSL
  precondition requires too.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| AXPY-A1 | proved | proved | – |
| AXPY-A2 | proved | proved | – |
| AXPY-A3 | proved | proved | – |
| AXPY-B1 | – | proved | – |
| AXPY-B2 | – | proved | – |
| AXPY-C1 | – | – | 75/75 goals (Frama-C 32.1, Alt-Ergo 2.6.4), no assumed contract |
| AXPY-C2 | – | proved | – |
| AXPY-C3 | – | proved | – |
