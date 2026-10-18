---
id: PROOF-007
title: Three models per kernel and how layers A, B and C compose
kind: fact
path:
  - spec/*.md
related: [VST-001, VST-005, WP-003, FP-005, COMPILER-001, GATE-001]
---
Each kernel has three models: a real-number model (layer A), a binary64 model in the C's
operation order (layer B), and the C function (layer C). `rspec` and `fmodel` are schematic names
for the first two, not identifiers in `verification/`; each `spec/<method>.md` names the real
definitions under "Model correspondence".

- Layer A: the exact method (`step`, `iterate`, `rk4` with `incT`, the quadrature sums), proved
  separately in Lean 4 with Mathlib and in Rocq with Stdlib reals (Coquelicot where needed).
- Layer B, Rocq only: Flocq models (`fstep`, `ftrap`, `fsimpson`, `feuler`, `frk4_stage`,
  `frk4_step`, `fchol`, `ffwd`, `fbwd`) from `Bplus`, `Bmult`, `Bdiv`, `Bminus` and `Bsqrt` in
  `mode_NE`, over NaN-payload functions.
- Layer C has two tools. Frama-C WP proves each source file's ACSL contract: memory safety, no
  undefined behaviour, separation, the condition behind each status, untouched output on error,
  but no computed value of the array kernels. VST proves that each function of the
  AArch64 macOS Clight AST (VST-001) computes a C-order model (`c_init`, `c_step`, `c_trap`,
  `c_simpson`, `c_euler`, `c_stage`, `c_rk4`) written in CompCert's `Float` operations;
  Cholesky's `c_l` and the substitution models `c_fwd`, `c_bwd` are the Flocq `fchol`, `ffwd`,
  `fbwd` at CompCert's NaN functions, equal by conversion.
- C to B: CompCert's `Float.add`, `Float.mul`, `Float.div`, `Float.sub` are Flocq's `Bplus`,
  `Bmult`, `Bdiv`, `Bminus` at CompCert's NaN-payload function, so a model theorem
  (`c_trap_model`, `c_simpson_model`, `c_euler_model`, BISECTION-C10, NEWTON-C7, RK4-C5, C6)
  identifies the C-order model with the Flocq one inside one Rocq development, with no
  translation step, and the layer-B theorems apply to what the C writes.
- B to A: the forward-error theorems (TRAPEZOIDAL-B2, SIMPSON-B2, EULER-B2, NEWTON-B2, RK4-B3,
  RK4-B5, SUBSTITUTION-B2, B4) bound the binary64 result against the exact evaluation of the same
  formula on the same inputs, the layer-A rule, step or solve. Bisection's layer B instead restates
  the A1 invariant for its own `fstep`. The unchecked kernels have layer-B finiteness theorems and
  no layer A.
- Not composed: no listed theorem chains A and B end to end. The trapezoidal "Composition"
  section is a derivation, and nothing carries per-step rounding through EULER-A2 or RK4-A7.
  VST funspecs exclude the argument-error paths, which WP covers; the per-function proofs are
  not linked into a `semax_prog` (VST-005); the shipped gcc or clang binary is tied to the
  CompCert semantics by argument and the compiler comparison, not by proof (FP-005,
  COMPILER-001).
