# Trust statement

What the verification layers of Diana mean, where the trust boundaries are, and where each layer is
checked. The status of every theorem is in the generated [report](report.md).

## Layers

| Layer | Object | Tool | Statement |
|---|---|---|---|
| A | real-number model of the algorithm | Lean 4 + Mathlib **and** Rocq (Stdlib reals, Coquelicot) | convergence, invariants, error bounds over ℝ |
| B | binary64 model of the C arithmetic | Rocq + Flocq | rounding facts the C code relies on (finiteness, bracket containment, forward error) |
| C-VST | the C source (Clight AST) | Rocq + VST, via CompCert `clightgen` | a C function returns / updates exactly the layer-B model value (every function of the verified kernels: `diana_bisection_mid`, `diana_bisection_init`, `diana_bisection_step`, `diana_bisection_result`, `diana_trapezoidal`, `diana_simpson`, `diana_euler_step`, `diana_euler_step_unchecked`, `diana_rk4_stage`, `diana_rk4_stage_unchecked`, `diana_rk4_step`, `diana_rk4_step_unchecked`, `diana_newton_init`, `diana_newton_step`, `diana_newton_result`, and the `src/fp.h` helpers) |
| C-WP | the C source | Frama-C WP, float model, RTE plugin | memory safety, absence of undefined behaviour, separation, contract invariants |

The three models of a kernel are: `rspec` (ℝ), `fmodel` (Flocq, same operation order as the C),
and the C function. VST proves C = `fmodel`; Flocq relates `fmodel` to `rspec`; layer A is about
`rspec`. CompCert's `Float.add`/`Float.mul` are Flocq's `Bplus`/`Bmult`, so B and C-VST compose
inside one Rocq development with no translation step.

## Trust base

- The Lean 4 kernel and Mathlib; axioms limited to `propext`, `Classical.choice`, `Quot.sound`
  (checked per theorem by `script/check_spec.py --run`, the [spec gate](spec-gate.md)).
- The Rocq kernel, Coquelicot, Flocq, VST, and CompCert's Clight semantics; axioms limited to
  classical reals and functional extensionality (checked the same way), plus any VST axiom listed in
  `script/axiom_allow.yaml`.
- Frama-C 33.0 / Why3 1.8.2 / Alt-Ergo 2.6.4 as a proof oracle for layer C-WP. WP assumes the
  contracts of the functions listed in `SKIP` in `script/run_frama_c.sh`; each such contract is a
  layer-B theorem (currently only `diana_bisection_mid`, discharged by BISECTION-B1; see
  [Frama-C and Flocq boundary](frama-c.md)).
- `clightgen` as the translation from C to Clight. The committed
  `verification/clight/<source>_<target>.v`, one per verified source file (today
  `bisection_init_aarch64_macos.v`, `bisection_mid_aarch64_macos.v`,
  `bisection_result_aarch64_macos.v`, `bisection_step_aarch64_macos.v`, `euler_aarch64_macos.v`,
  `euler_step_unchecked_aarch64_macos.v`, `newton_init_aarch64_macos.v`,
  `newton_result_aarch64_macos.v`, `newton_step_aarch64_macos.v`, `rk4_stage_aarch64_macos.v`,
  `rk4_stage_unchecked_aarch64_macos.v`, `rk4_step_aarch64_macos.v`,
  `rk4_step_unchecked_aarch64_macos.v`, `simpson_aarch64_macos.v` and
  `trapezoidal_aarch64_macos.v`, CompCert configured for AArch64 macOS) is generated locally on that target and is the AST the VST proofs are about;
  CI neither regenerates nor re-proves it.

## Where each layer is checked

| Layer | CI | Local ([local verification](local.md)) |
|---|---|---|
| A, Lean | `verify_lean`: build and strict axiom gate (`--prover lean`) | `lake build`, `check_spec.py --run --strict` |
| A, Rocq | `verify_rocq`: compilation only | `make`, `make check`, `check_spec.py --run --strict` |
| B (Flocq), C-VST, Clight AST | – | `clightgen`, `make`, `make check`, `check_spec.py --run --strict` |
| C-WP | `verify_frama_c` (Frama-C 32.1) | `script/run_frama_c.sh` (Frama-C 33.0) |
| `ccomp` build versus gcc/clang build | – (ctest `compiler` only runs the driver) | `script/compare_compiler.sh` |

A green pipeline therefore does not establish layers B and C-VST, and the CI Frama-C result assumes
the contract of `diana_bisection_mid`, which only the local Flocq build (BISECTION-B1) discharges.
The statuses in the [report](report.md) come from the last local `check_spec.py --run` that was
committed.

## Verified artifact versus shipped binary

The VST proof is about CompCert's Clight semantics, so it carries to a `ccomp`-compiled binary. The
shipped library is built with gcc or clang with `-std=c11 -ffp-contract=off -fno-fast-math` (and
`-fexcess-precision=standard` on gcc) on x86-64 SSE2 or AArch64: no x87 excess precision and no FMA
contraction. The model also assumes the calling thread uses round-to-nearest, ties-to-even,
gradual underflow (no flush-to-zero or denormals-are-zero mode), and disabled floating-point
traps. Compiler flags do not establish these runtime settings. Diana neither checks nor changes
them; callers, including callbacks, must maintain the
[API floating-point environment](../api/overview.md#floating-point-environment).
Under these conditions the arithmetic follows the IEEE binary64 sequence the model describes.
This equivalence is an argument, not a theorem. A bitwise differential test backs it:
`script/compare_compiler.sh` builds the kernels with the corpus driver `test/c/test_compiler.c`
once with `ccomp` and with each available gcc and clang at `-O0`, `-O2` and `-O3` under the flags
above, and fails unless every host build prints exactly the bytes the `ccomp` build prints. The
driver prints every status and every double as its bit pattern, so the sign of zero counts, for
2464 cases: every argument error, NaN and ±∞ inputs, `h = ±0`, subnormals, overflow in each
operation, the operation-order cases of the ctest suites, the 2098-step bisection worst case step
by step, the Newton two-cycle, and seeded random inputs ([compiler comparison](compiler.md)). On
AArch64 macOS,
Apple clang 21, Homebrew GCC 13.4, 14.4, 15.3 and 16.2, and Homebrew LLVM clang 20.1, 21.1, 22.1
and 23.1 match CompCert 3.17 on all of it.
This is evidence on a finite corpus, not a proof, and it only covers the platform it runs on: no
x86-64 build has been compared yet. CompCert is not in CI, so the test runs locally, as a step of
`script/dev.sh verify`.

## Not verified

- The callback wrappers in `src/wrapper/` and the Python package: the Python loop drives the
  verified state machine, but the loop and the CPython extension are ordinary tested code.
- The build system, the compilers, and the operating system.
- Under VST, the argument-error paths a funspec excludes by its precondition: a NULL pointer in
  every kernel, `d = 0`, `n < 2`, `n < 3` or an even `n` in the array kernels, and an RK4 stage
  outside 2 to 4. The Frama-C contracts cover them (BISECTION-C2 to C4, EULER-C1,
  EULER-UNCHECKED-C1, NEWTON-C1 to C3, RK4-C1, RK4-C2, RK4-UNCHECKED-C1, RK4-UNCHECKED-C2,
  SIMPSON-C1, TRAPEZOIDAL-C1).
- The composition of the per-function VST proofs. Each `semax_body` assumes the funspecs of the
  functions it calls, and no proof links them into a whole-program `semax_prog`. For the one call
  across source files, from `diana_bisection_init`, `diana_bisection_step` and
  `diana_bisection_result` to `diana_bisection_mid`, the callers use the funspec that BISECTION-C1
  proves of the callee (`Diana.VST.BisectionMid.mid_spec`); the system linker, not CompCert, joins
  the object files.
- Termination of Newton's method: `max_iter` bounds the step count, and no theorem says the
  iteration converges from a given `x0` in binary64 (NEWTON-A2 is about exact arithmetic and a
  start within the basin it describes).
- An explicit numeric bound on the bisection step count. BISECTION-B4 proves termination and the
  sound but loose bound `n <= lattice` (the number of doubles the bracket spans); the
  `max_iter = 2100` default is justified by the measured and ctest-pinned worst case of 2098 steps,
  not by a theorem (`spec/bisection.md`, "What B4 does not say").
- A theorem not yet proved is listed as `missing` in the report, and one whose prover project is
  absent as `planned`.
