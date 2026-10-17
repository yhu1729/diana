# Spec gate

`script/check_spec.py` reads the YAML front matter of every `spec/<method>.md` (theorem id, layer
A real / B float / C code, informal statement, and the fully qualified constant per prover) and

1. validates the front matter and the referenced C targets; a theorem ID is the method in
   capitals with `_` written as `-`, the layer letter, and a number (`BISECTION-A1` in
   `spec/bisection.md`, `EULER-UNCHECKED-C1` in `spec/euler_unchecked.md`), and `kernel` names
   one source file or a list of them;
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
4. rewrites the [report](report.md) when both provers ran (`--run` without `--prover`, unless
   `--no-report`); a structural check or a one-prover run leaves the committed report alone, since
   it would show a prover that did not run as `planned`. The Frama-C column reads the committed
   goal count `verification/frama-c/expectation.txt`, which CI compares against a fresh WP run.

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
