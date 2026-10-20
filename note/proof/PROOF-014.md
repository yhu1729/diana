---
id: PROOF-014
title: Axpy theorems, their hypotheses and the Euler lemmas they reuse
kind: fact
path:
  - spec/axpy.md
  - src/axpy.c
related: [PROOF-005, PROOF-007, PROOF-013, API-039, VST-004]
---
Axpy is proved through every layer (`spec/axpy.md`), the vectors as lists as for the norms.

- Layer A, Lean and Rocq: `axpy a x y = add (map (a·) x) y`. A1 `‖a·x + y‖ ≤ |a|·‖x‖ + ‖y‖`
  for the 1-, 2- and maximum norms of `spec/norm.md` (NORM-A4 and A5 applied to `map (a·) x`
  and `y`); A2 `axpy a x (axpy b x y) = axpy (a + b) x y`; A3 `axpy 0 x y = y` and
  `axpy (−a) x (axpy a x y) = y`. A1 and A3 take equal lengths, since the entrywise sum is as
  long as the shorter list.
- Layer B, Rocq and Flocq: one component `fupdate a x y = fadd y (fmul a x)` is by definition
  the Euler step `fstep a y x` of `Diana.Float.Euler`, so B1 (a finite component certifies
  `a`, `xᵢ`, `yᵢ` and the product finite) and B2
  (`|r − (a·xᵢ + yᵢ)| ≤ u·|a·xᵢ + yᵢ| + (1 + u)·(u·|a·xᵢ| + η)`, `u = 2⁻⁵³`, `η = 2⁻¹⁰⁷⁵`) are
  EULER-B1 and EULER-B2 with `h := a`, `y := y`, `f := x`; nothing is proved twice.
- Layer C: WP proves memory safety, termination, the status set, the exact condition of each
  status (a finite `a` on `DIANA_OK` and `DIANA_ERR_OVERFLOW`, a witness of the non-finite
  input on `DIANA_ERR_ARG`) and `y` untouched on both errors (C1, 75 goals, no assumed
  contract). VST (C2) proves for `n ≥ 1` that the kernel computes `c_axpy a xs ys`, equal to the
  Flocq `faxpy`, with the exact status `axpy_status`; C3 is the `diana_fp_finite` copy.
- Limits: the bound is per component and relative to `|a·xᵢ + yᵢ|` and `|a·xᵢ|`, so it says
  nothing about cancellation between `a·xᵢ` and `yᵢ` beyond `u` times the exact result; the
  VST funspec takes `x` and `y` disjoint, as the ACSL precondition requires.
