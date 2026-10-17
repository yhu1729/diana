# Local workflow

`script/dev.sh <command>` runs the local steps from the repository root:

- `config [cmake option...]`: `uv sync` with the `test`, `lint`, and `spec` groups, then
  configures `DIANA_BUILD_DIR` (default `build`, separate from scikit-build's `build/<wheel tag>`)
  with tests on, `DIANA_BUILD_TYPE` (default `Debug`), `DIANA_SANITIZER` (default `ON`), and
  `Python_EXECUTABLE` set to `.venv/bin/python`, using Ninja when available.
- `build`: `cmake --build`, then `uv sync --reinstall-package diana`, because uv does not rebuild
  the extension when only C sources change.
- `test`: ctest (including `install`/`find_package`), pytest, ruff, the `clang-format` check of
  `style_c`, and `clang-tidy` when one is found ([format and lint](style.md)).
- `verify`: the steps of [local verification](../verification/local.md), with the Clight step as a
  check, and the [compiler comparison](../verification/compiler.md) after it. Rocq, CompCert, and
  Frama-C run through `opam exec` in `DIANA_OPAM_SWITCH` (default: the current switch), so a
  Homebrew `rocq` on `PATH` is not picked up. After the Clight check the comparison, the Lean
  build, the Rocq build and the WP rows run at once, logging to `build/verify/`, with `DIANA_JOB`
  (default: the CPU count) Rocq jobs, capped by memory, and WP rows in flight; `DIANA_JOB=1` runs
  them one after another on the terminal ([parallel run](../verification/local.md#parallel-run)).

## Verify timing

`time script/dev.sh verify` on an Apple M4 (10 cores, 24 GB), Rocq 9.2.0, Frama-C 32.1, Alt-Ergo
2.6.4, Lean 4.35.0 with the Mathlib cache present. Cold: after `make clean` in
`verification/rocq`, with `verification/frama-c/cache` removed and the Lean `.lake/build` of the
Diana modules removed. Warm: a second run with nothing changed. The sequential column is the
stage order before the parallel run (`DIANA_JOB=1`), measured per stage.

| Stage | Sequential, cold | Sequential, warm | `DIANA_JOB=10`, cold | `DIANA_JOB=10`, warm |
|---|---|---|---|---|
| Clight check | 2 | 2 | 2 | 2 |
| Compiler comparison | 49 | 51 | 99 | 52 |
| Lean build | 133 | 116 | 203 | 89 |
| Rocq build | 187 | 0 | 73 | 0 |
| WP rows | 85 | 89 | 80 | 27 |
| Spec gate | 132 | 148 | 122 | 161 |
| Total | 588 | 406 | 327 | 252 |

Seconds. The sequential columns are the stages run one after another, each timed on its own;
the `DIANA_JOB=10` columns are one `script/dev.sh verify` each, whose total is wall-clock time:
the four middle stages overlap, their times are those of `build/verify/*.status` under that
contention, and the spec gate is the remainder after the longest of them. The Lean build sets
the parallel total in both runs (warm, `lake exe cache get` alone takes most of its time), so the
Rocq build (10 jobs, 187 to 73 s) and the WP rows (85 to 27 s warm) no longer appear in it; the
spec gate, which rebuilds the Lean and Rocq check files, is now the largest single cost. The same
warm state through `DIANA_JOB=1 script/dev.sh verify` took 360 s. Every run left
`doc/verification/report.md` unchanged.
