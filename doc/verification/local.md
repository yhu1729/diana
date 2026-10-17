# Local verification

CI checks the C code (build, ctest, pytest, Frama-C WP), layer A in Lean with its axiom gate, and
that layer A compiles in Rocq. Everything that needs Flocq, CompCert, or VST runs only in the opam
switch of `CONTRIBUTING.md`, and a green pipeline says nothing about it. After a change to `src/`,
`include/`, `verification/`, or `spec/` (`script/dev.sh verify` runs all five):

1. If a verified kernel or a header it includes changed, regenerate its Clight AST with the
   `clightgen` command in `CLAUDE.md`. Nothing in CI notices a stale AST. `script/dev.sh verify`
   reads the CompCert target from `compcert.config` in the opam switch, regenerates every
   `verification/clight/<kernel>_<target>.v` of that target from `src/<kernel>.c` into a temporary
   file, and fails if it differs from the committed one; with `DIANA_CLIGHT_UPDATE=1` it
   overwrites the committed file and goes on, so the Rocq build then checks the proofs against the
   new AST. On a target with no committed AST it skips the check.
2. `script/compare_compiler.sh` checks that the `ccomp` build of the kernels and gcc/clang builds
   print the same bits on the corpus of `test/c/test_compiler.c`; see
   [compiler comparison](compiler.md). Without `ccomp` it skips the check.
3. `cd verification/rocq && make && make check` builds layers A, B, and C-VST and prints their
   axioms. `make check` needs the generated `CheckSpec.v`, which step 5 writes; on a fresh clone
   run step 5 first, or just use `script/dev.sh verify`, which orders them.
4. `script/verify_frama_c.sh` runs `script/run_frama_c.sh` and `script/check_frama_c.sh` for
   each `<source> <goal-count>` row of `verification/frama-c/expectation.txt`, with reports in
   one consolidated `verification/frama-c/report.txt`, one `==> <source> <==` section per row
   (CI runs the same script with Frama-C 32.1 and uploads that single file).
5. `uv run script/check_spec.py --run --strict` runs both provers' axiom gates and rewrites the
   [report](report.md); commit the report. `--strict` is what
   `script/dev.sh verify` passes, so `verify` fails on a theorem that is listed in `spec/` but not
   proved (`missing`), not only on a disallowed axiom. The full strict gate also requires exactly
   one valid positive Frama-C expectation count for the `acsl` file of each ACSL theorem, so the WP
   loop cannot silently omit it. The fresh WP run and report check remain step 4; an expectation
   count alone is not proof evidence. As of v0.3.0 every theorem listed in `spec/` is proved, so it
   exits 0. Note that this is a gate on the listed theorems, not a claim beyond them: the callback
   wrappers (`src/bisection.c`, `src/euler.c`, `src/newton.c`, `src/rk4.c`) have no proof, and the
   VST funspecs leave the NULL and other argument-error paths to Frama-C.

## Clight AST per target

`clightgen` output depends on the target CompCert was configured for (the `Info` module records the
architecture and ABI, and the builtin list differs between AArch64 and x86-64), so each AST is named
after its target, `<arch>[_<model>]_<system>` from `compcert.config`
(`bisection_init_aarch64_macos.v`; an x86-64 Linux one would be `bisection_init_x86_64_linux.v`),
and the VST proofs import that module by name. Regenerate an AST only on its own target, and commit
it only together with the source change that caused it and a passing `make`. On another target the
Rocq build is expected to compile the proofs against the committed AST (not yet checked on a
non-macOS target), but cannot regenerate it. A second target needs its own CompCert switch and a
second committed AST.

## Rocq build

`verification/rocq/Makefile` requires the opam switch described in `CONTRIBUTING.md`. `make` builds
everything and `make check` prints the axioms of the listed theorems; `check` compiles the generated
`CheckSpec.v`, so run `uv run script/check_spec.py --run --prover rocq` (or `script/dev.sh verify`)
at least once first, because that file is generated and not committed. `make real` builds layer A
only (Stdlib and Coquelicot), which is what the `verify_rocq` image can build; it calls
`rocq compile` directly because the generated makefile scans the dependencies of every file in
`_CoqProject` and warns that Flocq, CompCert, and VST are missing.
