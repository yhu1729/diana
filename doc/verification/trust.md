# Trust statement

What the proofs of Diana establish, what they rely on, and what is only tested. The status of
every theorem is in the generated [report](report.md); the theorems themselves are listed per
method in `spec/<method>.md`.

## Three layers

Each method is described three times, and proofs connect the descriptions:

| Layer | Object | Tool | What is proved |
|---|---|---|---|
| A | the algorithm over the real numbers | Lean 4 with Mathlib, and Rocq with Coquelicot | convergence, invariants and error bounds in exact arithmetic |
| B | a binary64 model of the algorithm, in the C's operation order | Rocq with Flocq | what rounding does: finiteness, bracket containment, forward error |
| C | the C source | VST (Rocq) and Frama-C WP | VST: each function computes exactly the layer-B value; WP: memory safety, no undefined behaviour, the ACSL contract |

Layer A is proved twice, independently, in Lean and in Rocq. CompCert's floating-point
operations are Flocq's, so layers B and C-VST compose inside one Rocq development with no
translation step. Every function of the verified kernels has both a VST proof and a Frama-C proof;
the VST proofs leave the argument-error paths (`NULL` pointers, `d = 0` and the like) to Frama-C.
The opt-in `_unchecked` kernels have no layer A of their own: their layer B shows that a written
component is finite exactly when the checked kernel would have accepted it.

## What is trusted

- **Proof checkers.** The Lean kernel and Mathlib; the Rocq kernel with Coquelicot, Flocq, VST and
  CompCert's Clight semantics. The [spec gate](spec-gate.md) checks that each listed theorem uses
  only allowed axioms: Lean's three standard ones, and in Rocq classical logic, the classical reals
  and functional and propositional extensionality (`script/axiom_allow.yaml`).
- **Frama-C, Why3 and Alt-Ergo** as the prover of the WP layer. WP assumes the contract of one
  function it cannot prove, the bisection midpoint `diana_bisection_mid`; Flocq and VST prove
  that function instead, and the WP script fails if any other contract would be assumed.
- **`clightgen`**, which translates the C source into the Clight AST the VST proofs are about. The
  ASTs are generated on AArch64 macOS and committed.
- **The compiler** of the shipped library; see below.
- **The statements.** The gate checks that each named theorem exists and is proved, not that its
  formal statement says what its informal text says; that correspondence is reviewed.

## Where each layer is checked

| Layer | CI | Local ([local verification](local.md)) |
|---|---|---|
| A, Lean | `verify_lean`: build and axiom gate | `script/dev.sh verify` |
| A, Rocq | `verify_rocq`: compilation only | `script/dev.sh verify` |
| B, C-VST, Clight AST | – | `script/dev.sh verify` |
| C-WP | `verify_frama_c` | `script/verify_frama_c.sh` |
| `ccomp` against gcc/clang | – | `script/compare_compiler.sh` |

No CI image carries Flocq, CompCert or VST, so a green pipeline does not establish layers B and
C-VST, and the CI Frama-C run relies on the midpoint contract that only the local Flocq build
discharges. The [report](report.md) shows the last local run that was committed.

## Verified code versus shipped library

VST reasons about CompCert's semantics, so its result carries directly to a library compiled with
CompCert's `ccomp`. The shipped library is built with gcc or clang instead, with strict IEEE
settings: no fused multiply-add contraction, no fast-math, and no evaluation of `double` in a wider
format (a compile-time check). With those settings, and the
[runtime floating-point environment](../api/overview.md#floating-point-environment), both
compilers perform the same sequence of IEEE binary64 operations. That equivalence is an argument,
not a theorem. The [compiler comparison](compiler.md) backs it with a bitwise test on a fixed
corpus, so far run only on AArch64 macOS.

## Not verified

- The callback wrappers (`diana_bisection`, `diana_newton`, `diana_euler`, `diana_rk4`) and the
  Python package: tested, not proved.
- The build system, the compilers and the operating system.
- The composition of the per-function VST proofs into one whole-program proof.
- That Newton's method converges in binary64 from a given start; `max_iter` is the only bound.
- A numeric bound on the number of bisection steps; the worst case of 2098 is measured.
- A bound on the rounding error accumulated over many ODE steps.

## Technical notes

[PROOF-007](../../note/proof/PROOF-007.md) the three models,
[WP-003](../../note/wp/WP-003.md) the `SKIP` trust boundary,
[VST-005](../../note/vst/VST-005.md) per-function proofs,
[VST-007](../../note/vst/VST-007.md) argument-error paths,
[FP-005](../../note/fp/FP-005.md) verified versus shipped binary,
[GATE-005](../../note/gate/GATE-005.md) allowed axioms,
[GATE-008](../../note/gate/GATE-008.md) what the gate does not check.
