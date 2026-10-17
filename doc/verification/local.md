# Local verification

CI builds and tests the code, runs Frama-C, and checks layer A in Lean and Rocq. Everything that
needs Flocq, CompCert or VST — layer B, the VST proofs, the Rocq axiom gate, the Clight ASTs and
the compiler comparison — runs only on a developer machine, in the opam switch that
`CONTRIBUTING.md` sets up. A green pipeline says nothing about those. So after any change to
`src/`, `include/`, `verification/` or `spec/`, run

```bash
script/dev.sh verify
```

and commit the report it rewrites, `doc/verification/report.md`. It fails on anything below that
does not hold, including a theorem listed in `spec/` that no prover proves.

## What it runs

1. **Clight check.** For each committed Clight AST of the current CompCert target, it regenerates
   the AST from its source and fails if the two differ. After a change to a verified kernel or a
   header it includes, rerun with `DIANA_CLIGHT_UPDATE=1` to overwrite the ASTs, and commit them
   with the source change. The ASTs are named after their target
   (`bisection_init_aarch64_macos.v`) and must only be regenerated on that target; on another
   target the check is skipped.
2. **At the same time:** the [compiler comparison](compiler.md), the Lean build, the Rocq build
   (layers A, B and C-VST) and Frama-C WP on every source. Each writes a log under
   `build/verify/`; `DIANA_JOB` sets how many Rocq jobs and Frama-C rows run at once (default: the
   CPU count, capped by memory for Rocq), and `DIANA_JOB=1` runs the stages one after another on
   the terminal, which is easier to debug.
3. **Spec gate.** `check_spec.py --run --strict` checks the axioms of every listed theorem and
   rewrites the report (see [spec gate](spec-gate.md)).

On an Apple M4 a warm run takes about four minutes and a cold one about five and a half.

## Running a step alone

| Step | Command |
|---|---|
| Rocq proofs | `cd verification/rocq && make -j4` (then `make check` prints the axioms; it needs the file the spec gate generates) |
| Lean proofs | `cd verification/lean && lake exe cache get && lake build` |
| Frama-C | `script/verify_frama_c.sh` |
| Compiler comparison | `opam exec -- script/compare_compiler.sh` |
| Spec gate | `uv run script/check_spec.py --run --strict` |

## Technical notes

[VERIFY-001](../../note/verify/VERIFY-001.md) checks that run only locally,
[VERIFY-002](../../note/verify/VERIFY-002.md) stage order,
[VERIFY-003](../../note/verify/VERIFY-003.md) parallel run and logs,
[VERIFY-004](../../note/verify/VERIFY-004.md) timing,
[VST-001](../../note/vst/VST-001.md) AST naming per target,
[VST-002](../../note/vst/VST-002.md) regenerating an AST,
[PROVER-007](../../note/prover/PROVER-007.md) Rocq build targets,
[PROVER-008](../../note/prover/PROVER-008.md) Rocq memory cap.
