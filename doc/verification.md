# Verification

This file is the trust statement for Diana: what the layers mean, where the trust boundaries are,
and, in the generated [report](#report) at the end, the status of every theorem.

## Layers

| Layer | Object | Tool | Statement |
|---|---|---|---|
| A | real-number model of the algorithm | Lean 4 + Mathlib **and** Rocq (Stdlib reals) | convergence, invariants, error bounds over ℝ |
| B | binary64 model of the C arithmetic | Rocq + Flocq | rounding facts the C code relies on (finiteness, bracket containment, forward error) |
| C-VST | the C source (Clight AST) | Rocq + VST, via CompCert `clightgen` | a C function returns / updates exactly the layer-B model value (so far `bisect_mid`, `diana_bisect_result`, and the `src/fp.h` helpers) |
| C-WP | the C source | Frama-C WP, float model, RTE plugin | memory safety, absence of undefined behaviour, separation, contract invariants |

The three models of a kernel are: `rspec` (ℝ), `fmodel` (Flocq, same operation order as the C),
and the C function. VST proves C = `fmodel`; Flocq relates `fmodel` to `rspec`; layer A is about
`rspec`. CompCert's `Float.add`/`Float.mul` are Flocq's `Bplus`/`Bmult`, so B and C-VST compose
inside one Rocq development with no translation step.

## Trust base

- The Lean 4 kernel and Mathlib; axioms limited to `propext`, `Classical.choice`, `Quot.sound`
  (checked per theorem by `script/check_spec.py --run`).
- The Rocq kernel, Flocq, VST, and CompCert's Clight semantics; axioms limited to
  classical reals and functional extensionality (checked the same way), plus any VST axiom listed in
  `script/axiom_allow.yaml`.
- Frama-C 33.0 / Why3 1.8.2 / Alt-Ergo 2.6.4 as a proof oracle for layer C-WP. WP assumes the
  contracts of the functions listed in `SKIP` in `script/run_frama_c.sh`; each such contract is a
  layer-B theorem (currently only `bisect_mid`, discharged by BIS-B1).
- `clightgen` as the translation from C to Clight. The committed
  `verification/clight/<kernel>_<target>.v` (today `bisect_aarch64_macos.v`, CompCert configured
  for AArch64 macOS) is generated locally on that target and is the AST the VST proofs are about;
  CI neither regenerates nor re-proves it.

## Where each layer is checked

| Layer | CI | Local (`doc/development.md`, Local verification) |
|---|---|---|
| A, Lean | `verify_lean`: build and strict axiom gate (`--prover lean`) | `lake build`, `check_spec.py --run --strict` |
| A, Rocq | `verify_rocq`: compilation only | `make`, `make check`, `check_spec.py --run --strict` |
| B (Flocq), C-VST, Clight AST | – | `clightgen`, `make`, `make check`, `check_spec.py --run --strict` |
| C-WP | `verify_frama_c` (Frama-C 32.1) | `script/run_frama_c.sh` (Frama-C 33.0) |

A green pipeline therefore does not establish layers B and C-VST, and the CI Frama-C result
assumes the contract of `bisect_mid`, which only the local Flocq build (BIS-B1) discharges. The
statuses in the [report](#report) come from the last local `check_spec.py --run` that was committed.

## Verified artifact versus shipped binary

The VST proof is about CompCert's Clight semantics, so it carries to a `ccomp`-compiled binary. The
shipped library is built with gcc or clang with `-std=c11 -ffp-contract=off -fno-fast-math` (and
`-fexcess-precision=standard` on gcc) on x86-64 SSE2 or AArch64: no x87 excess precision, no FMA
contraction, so the arithmetic is the same IEEE binary64 round-to-nearest sequence the model
describes. This equivalence is an argument, not a theorem; planned bitwise differential tests
between the `ccomp` and gcc/clang builds will back it. CompCert is not in CI, so they run locally.

## Not verified

- The callback wrappers in `src/wrapper/` and the Python package: the Python loop drives the
  verified state machine, but the loop and the CPython extension are ordinary tested code.
- The build system, the compilers, and the operating system.
- `diana_bisect_init` and `diana_bisect_step` under VST: no theorem yet says their post-state is
  the layer-B model. Frama-C WP does cover them (BIS-C2), so layer C is not empty for them, and
  layer B models the step (BIS-B2/B3/B4); what is missing is the C-to-model link for those two
  functions. See `spec/bisect.md`.
- An explicit numeric bound on the bisection step count. BIS-B4 proves termination and the sound
  but loose bound `n <= lattice` (the number of doubles the bracket spans); the `max_iter = 2100`
  default is justified by the measured and ctest-pinned worst case of 2098 steps, not by a theorem
  (`spec/bisect.md`, "What B4 does not say").
- A theorem not yet proved is listed as `missing` in the report, and one whose prover project is
  absent as `planned`.

## Frama-C and Flocq boundary

ACSL arithmetic on doubles is exact real arithmetic; rounded values are written with casts. The
bound `DBL_MAX/2 = (2^53 - 1) * 2^970` appears twice in `src/bisect.c`: `DIANA_BISECT_MAX` for C (an
exact power-of-two scaling) and `DIANA_BISECT_MAX_ACSL` as an exact integer expression, because
WP (Frama-C 33.0) rejects hexadecimal float literals in lemmas and mistranslates them in predicates.

The midpoint-in-bracket fact is beyond the SMT float model, so the kernel computes the midpoint in
the static helper `bisect_mid`. `script/run_frama_c.sh` passes it to `-wp-skip-fct` (variable `SKIP`),
so WP assumes its contract; Flocq proves it as BIS-B1 (`mid_in_bracket` in
`verification/rocq/theory/Float/Bisect.v`), and VST proves the C body against that model (BIS-C1).
`SKIP` is the explicit trust boundary between layer C-WP and layer B: every entry needs a layer-B
theorem.

The ACSL predicate `bisect_bracket` is a strict sign change or a bracket collapsed onto an exact
root, the same as `SignChange` in the Lean and Rocq layer-A models. A weak sign change
(`fa * fb <= 0`) is not preserved by the sign test `(fx > 0) == (fa > 0)` when `fa == 0`.

`script/run_frama_c.sh [file...]` runs WP (float model, RTE, Alt-Ergo, 30 s timeout) over the given
kernels (default `src/bisect.c`). WP does not set a non-zero exit status for an unproved goal,
so the report must always be checked: `script/check_frama_c.sh` is the gate.
`verification/frama-c/expectation.txt` stores one `<source> <goal-count>` row per verified C
file, currently `src/bisect.c 162`; the source path is the one WP runs on and the one an ACSL
theorem names in its `acsl` field. `script/check_frama_c.sh report.txt [source]` fails unless every
goal in the report is proved and, when a source is given, the goal count matches its row: a drop
means a contract or RTE guard silently disappeared. `script/verify_frama_c.sh` runs WP and this
check for every row, writing `verification/frama-c/report-<stem>.txt`; `script/dev.sh verify` and
the `verify_frama_c` CI job both call it, so CI and the local workflow check the same files. The count also moves with the statement structure, not
only with the annotations: WP checks an `assigns` clause in one part per write path, so adding
braces to `src/bisect.c` merged 12 `assigns_normal_part` goals (172 to 160) with every other goal
unchanged. Before changing `verification/frama-c/expectation.txt`, compare the goal lists of the old and
new source (`-wp-report-json`) and update the count only when no property kind disappeared.

## Floating-point helpers without libm

A verified kernel calls no external function: each call would need an axiomatised specification in
VST and Frama-C, and CompCert's `clightgen` cannot parse the macOS `<math.h>`. `src/fp.h` provides
pure IEEE arithmetic that Flocq models exactly:

- `diana_fp_finite(x)` is `x == x && x - x == 0`: NaN is the only value with `x != x`, and `x - x` is
  NaN for infinities and `+0` for every finite `x`.
- `diana_fp_abs(x)` is a conditional negation; for `-0.0` it returns `-0.0`, which compares equal to
  `0`.

## Spec gate

`script/check_spec.py` reads the YAML front matter of every `spec/<method>.md` (theorem id, layer
A real / B float / C code, informal statement, and the fully qualified constant per prover) and

1. validates the front matter and the referenced C targets;
2. writes `verification/lean/CheckSpec.lean` and `verification/rocq/CheckSpec.v`, which print the
   axioms of every listed constant. A constant not declared in its module file is marked `missing`
   and left out, so one absent constant does not abort the prover run for all others; the prover
   run stays the authority on what a constant proves;
3. with `--run`, runs each prover on its check file and compares the printed axioms with
   `script/axiom_allow.yaml`. Lean prints `'N' depends on axioms: [...]` or `'N' does not depend on
   any axioms`. Rocq's `Print Assumptions` prints `Closed under the global context` or an `Axioms:`
   block without echoing the name, so blocks are matched to constants by position; an axiom line
   starts at column 0 with the name, optionally followed by `: <type>`, while type continuation
   lines are indented. Because the match is positional, a block count that differs from the number
   of constants, an empty `Axioms:` block, or any unindented line that is not an axiom is an error
   rather than a silent reinterpretation: the affected constants read `check failed`. Only Rocq's
   stdout is parsed, since the pinned version writes warnings to stderr;
4. rewrites the report below (unless `--no-report`). The Frama-C column reads the committed goal count
   `verification/frama-c/expectation.txt`, which CI compares against a fresh WP run.

The exit status is non-zero on a structural error and, with `--strict`, also when any theorem is not
verified (missing prover project, missing constant, disallowed axiom). The default full strict gate
also requires exactly one valid positive Frama-C expectation count for the `acsl` file of every
ACSL theorem; since `script/verify_frama_c.sh` runs WP on exactly those rows, an ACSL file cannot
be silently left out of the WP run. Fresh WP execution and
report checking remain the responsibility of `script/dev.sh verify`, which passes `--strict`, so
the local gate fails on a theorem listed in `spec/` without a proof. The Lean CI
job also passes `--strict`, with `--prover lean` limiting the gate to listed Lean theorems, so
missing Lean proofs fail CI without requiring Rocq-only layers B and C-VST or Frama-C coverage.
Explicit `--prover` selections check only the named proof tools. The structural style
check stays non-strict, and Rocq CI still compiles layer A without running its axiom gate.

The allowed Rocq axioms are the classical reals of the Rocq standard library and functional
extensionality, the two that VST's own foundations rely on (`Axioms.prop_ext`,
`Ensembles.Extensionality_Ensembles`), and, once used, documented external-call semantics for VST
funspecs.

## Report

Status per theorem and prover: `ok` (constant exists, axioms within the allowed list), `planned`
(prover project absent), or the reason it is not verified.

<!-- generated by script/check_spec.py; do not edit below -->

| Spec | ID | Layer | Lean | Rocq | Frama-C | Statement |
|---|---|---|---|---|---|---|
| bisect | BIS-A1 | A | ok | ok | – | bracket invariant: ∀n, aₙ ≤ bₙ, f(aₙ)·f(bₙ) < 0 or aₙ = bₙ with f(aₙ) = 0, and bₙ − aₙ ≤ (b − a)/2ⁿ |
| bisect | BIS-A2 | A | ok | ok | – | ∃ x* ∈ [aₙ, bₙ] with f(x*) = 0, hence \|mₙ − x*\| ≤ (b − a)/2ⁿ⁺¹ |
| bisect | BIS-B1 | B | – | ok | – | binary64 model: with \|a\|,\|b\| ≤ DBL_MAX/2 and a ≤ b, the midpoint fl(0.5·fl(a+b)) is finite and lies in [a, b] (round-to-nearest-even; parameterised by the NaN-payload functions so it instantiates to CompCert's Float.add/Float.mul). |
| bisect | BIS-B2 | B | – | ok | – | the float bracket invariant of A1 holds for every step of the binary64 model: one step of fstep preserves finiteness, a <= b, \|a\|,\|b\| <= DBL_MAX/2 and the strict-sign-change-or- collapsed-root condition, and nests the bracket. |
| bisect | BIS-B3 | B | – | ok | – | with tol = 0 the iteration stops once the endpoints are adjacent doubles: when succ a = b the binary64 midpoint equals an endpoint, which is the kernel's DIANA_OK stop. |
| bisect | BIS-B4 | B | – | ok | – | termination: the bracket width is non-increasing, and the number of doubles it spans (lattice) strictly decreases on every continuing step, so a run of n consecutive DIANA_CONTINUE steps satisfies n <= lattice of the initial state. |
| bisect | BIS-C1 | C | – | ok | – | bisect_mid computes the model midpoint: Float.mul 0.5 (Float.add a b) = mid a b (VST, AArch64 macOS Clight AST) |
| bisect | BIS-C2 | C | – | – | ok (162/162) | ACSL contracts in src/bisect.c, Frama-C WP float model with RTE: memory safety, no UB, separation of outputs from the state, bracket predicate (strict sign change or collapsed root) preserved by init/step, iter increments, width is the rounded difference, and the state is unchanged when init or step reports an error. The only assumed contract is bisect_mid (-wp-skip-fct), discharged by BIS-B1. |
| bisect | BIS-C3 | C | – | ok | – | diana_fp_finite implements its IEEE semantics (VST, AArch64 macOS Clight AST): it returns 1 exactly when its argument is finite. |
| bisect | BIS-C4 | C | – | ok | – | diana_fp_abs returns the conditional negation the C performs (VST, AArch64 macOS Clight AST); c_abs_B2R identifies it with Rabs on finite input. |
| bisect | BIS-C5 | C | – | ok | – | diana_bisect_result writes the model midpoint and the rounded width (VST, AArch64 macOS Clight AST) |
