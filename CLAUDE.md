# Diana

Formally verified numerical method library in C11 with a hand-written CPython extension. The
mathematical specification is proven in both Lean 4 (Mathlib) and Rocq (Stdlib reals; Coquelicot
where integrals and derivatives are needed); floating-point bounds in Rocq (Flocq); C-code
correctness in Rocq (VST via CompCert `clightgen`) and Frama-C (WP).
Human documentation: `doc/README.md` (API `doc/api/`, development `doc/development/`, trust
statement `doc/verification/trust.md`, generated theorem report `doc/verification/report.md`).
**Technical notes for agents: `note/README.md`** — one fact, rule, procedure or rationale per
file (`note/<topic>/<PREFIX>-<NNN>.md`), indexed by topic and **by path**: before editing a file,
read the notes its "By path" row lists (`grep -rl '<path>' note`). Future work: `doc/roadmap.md`,
one line per idea, no design (a design is written only when an item is picked up).

## Convention

- **Name:** single-form noun and base-form verb everywhere: directory (`test/`, `verification/`, `script/`,
  `doc/`, `spec/`), identifier (`diana_bisection_init`, `check_spec`), CI job (`build`, `test`),
  Python API (`diana.bisection`). No plural, no `-ing`/`-s` verb form.
  - **Project name:** `Diana` in prose (heading, documentation sentence, user-facing string);
    lowercase `diana` only where it is an identifier (package, CMake target, library file, URL).
- **Commit:** `git commit -s` (Signed-off-by) always. Conventional Commits; the `commit-msg` hook accepts
  type `feat fix perf refactor build style test ci doc chore` (note `doc`, not `docs`). Never `--no-verify`.
  No push, tag, or merge request without an explicit request.
  - **No amend:** never `git commit --amend`; every commit keeps its author date equal to its
    commit date. To fix or rework commits, including ones a rebase replayed, `git reset --soft` to
    the last good commit and make fresh commits (`git read-tree <sha>` then `git commit -s` per
    original commit keeps each tree); a mistake in a published commit gets a new corrective commit.
  - **Rebase, not merge:** keep history linear with no merge commits. Bring a branch up to date,
    or combine branches, by rebasing onto the target (a branch that is already a descendant just
    fast-forwards), then recreate the replayed commits fresh as under **No amend**.
  - **Message:** subject line only — no body, no `Co-Authored-By` or other trailer, just the
    `Signed-off-by` line `-s` adds. Keep the subject at most 50 characters; drop articles
    (`add bisection header`, not `add the bisection header`) and name the thing, not the reason.
  - **Size:** one logical step per commit, usually one file (a header, a kernel, a test, a doc), at
    most a handful when they only make sense together (a `.c` with the `CMakeLists.txt` line that
    builds it). Split a change that touches the library, its test and its doc into one commit each.
  - **Check:** `script/check_commit.sh` enforces every rule above except size and wording beyond
    articles; the `pre-push` hook runs it on unpushed commits and the `style_git` CI job on the
    commits since the branch's previous pipeline (on the GitHub mirror, the commits of the push).
    Link both hooks once per clone (`CONTRIBUTING.md`).
- **Living document:** update `CHANGELOG.md` (`Unreleased` section, Keep a Changelog), this file,
  the affected `doc/` page and the affected notes in the same commit as any change that affects them.
- **Python:** `uv` manages the interpreter and environment (`uv sync` at the repo root; `.python-version`
  and `uv.lock` are committed). Never `pip` directly, never the system Python.
- **C:** C11, the strict warning set of `cmake/warning.cmake` (`-Wall -Wextra -Wpedantic -Wconversion -Wshadow -Wvla`
  and more, note BUILD-001) with `-Werror` (`-Werror` is the CMake option
  `DIANA_WERROR`, OFF by default so end-user builds survive new compiler warnings; CI and `script/dev.sh`
  turn it ON); no `malloc` and **no libm
  call** in a verified kernel (use `src/fp.h`: `diana_fp_finite`, `diana_fp_abs`; every external call
  would need an axiom in VST and Frama-C, and clightgen cannot parse macOS `<math.h>`; the one
  square root is `__builtin_sqrt` in `diana_fp_sqrt`, `src/fp_sqrt.c`, whose WP contract and VST
  funspec for the builtin are assumed, note FP-006); caller-owned
  buffer; every public function returns `diana_status` (except the string functions `diana_status_str`
  and `diana_version`), is listed in `cmake/symbol.txt` (a shared `libdiana` exports nothing else);
  prefix `diana_`; `-ffp-contract=off`, no
  `-ffast-math`/`-Ofast` (the verified semantics are strict IEEE binary64; configuration rejects
  fast-math, contraction and fast-model flags in `CMAKE_C_FLAGS*`, note FP-007, and a C compiler
  other than gcc or clang unless `DIANA_ALLOW_UNKNOWN_COMPILER=ON`, note BUILD-013); `-fno-math-errno` so the
  builtin square root needs no libm. Format with `clang-format`
  (LLVM style, `.clang-format`; use the version pinned in the uv `lint` group, CI `style_c` checks it).
- **Floating-point environment:** every numerical call requires nearest-even rounding, gradual
  underflow (no flush-to-zero or denormals-are-zero mode), and disabled traps on the calling
  thread. Diana does not check or change these settings; callbacks must preserve them. Compiler
  flags alone do not establish them (`doc/api/overview.md`).
- **Python binding:** C extension sources in `python/ext/` (`module.c` creates `diana._diana` and calls one
  `diana_py_<kernel>_exec` per kernel, in `<kernel>_exec.c` with the kernel's method and type tables;
  each method or function in its own file such as `bisection_step.c`; declarations and the
  `static inline` `diana_py_overlap` and `diana_py_square_side` in `module.h`, object structs in
  `bisection_object.h` and
  `newton_object.h`); pure-Python package in `python/src/diana/`
  with one private driver module per kernel (`_bisection.py`, `_newton.py`) re-exported by `__init__.py`, and
  `_convert.py` (`real`, the scalar check the bisection, Euler and RK4 drivers apply: a string is
  rejected as the C `d` converter rejects it; `diana.newton` passes its scalars to `Newton` directly).
  `Bisection` and `Newton` start with status `ERR_ARG` (their `status` is the C state's `status`
  field) until initialization succeeds; `step` and `result` reject
  uninitialized objects, and a failed reinitialization preserves the previous state. `Newton` takes `tol`
  without a default (no parameter-free stopping rule; `tol = 0` commonly ends in a two-cycle of adjacent doubles).
  An array kernel reads a buffer in place (`PyBUF_RECORDS_RO`, the extension's `out` buffer `PyBUF_RECORDS`; native float64, one-dimensional,
  C-contiguous, aligned, checked in the extension by `diana_py_get_array` in `python/ext/get_array.c`) and its driver copies any non-buffer iterable
  into `array.array("d")`; no NumPy in the package, only in tests.
- **ACSL:** arithmetic on doubles is exact real arithmetic, write rounded values with casts
  `(double)(...)`; no hexadecimal float literal anywhere in ACSL (WP 32.1 and 33.0 reject them in
  lemmas and mistranslate them in predicates), use exact integer expressions such as
  `((1 << 53) - 1) << 970`;
  a float fact that WP cannot prove goes into a small helper in its own source file
  (`src/bisection_mid.c`), with its contract on the declaration in a private header
  (`src/bisection_mid.h`), listed in `SKIP` of `script/run_frama_c.sh` and proved in Flocq. That
  skip list is the trust boundary between Frama-C and Rocq (the script fails when WP would assume
  the contract of a called, body-less function that is not in it, and on any called function
  with neither body nor contract, and when the two sections of the `frama-c -metrics` report it
  reads are not in their expected form, note WP-004); every entry needs a
  `BISECTION-B*`-style theorem. ACSL predicates and lemmas shared by the functions of a kernel go
  in a private header (`src/bisection_acsl.h`, `src/newton_acsl.h`, `src/substitution_acsl.h`;
  ACSL rejects `const` in a predicate's parameter types).
- **Verified kernel shape:** reverse communication. A kernel is a pure state machine on a caller-owned
  struct (`init` / `step` / `result`) or a function over tabulated arrays. No function pointer in a
  verified kernel. Callback convenience wrappers (`diana_bisection`, `diana_euler`, `diana_newton`,
  `diana_rk4`) are in `src/<method>.c`, declared in the method's header (the ODE callback type
  `diana_ode_fn` in `diana/ode.h`, the scalar one `diana_scalar_fn` in `diana/scalar.h`), and are not VST-verified.
- **One function per file:** each implementation file (`src/*.c`, `python/ext/*.c`) defines exactly
  one function, named after it without `diana_` or `diana_py_` (`src/bisection_init.c`,
  `src/status_str.c`, `python/ext/bisection_step.c`); `static inline` helpers do not count (those of
  `src/fp.h` are compiled into every file that includes them), static data such as a method table or
  type object stays with the function that registers it (`python/ext/bisection_exec.c`), and a
  helper several files call is a function and file of its own (`src/bisection_mid.c`).
  `PyInit__diana` is in `python/ext/module.c`; the tests are exempt. Each verified source file has
  its own WP expectation row, Clight AST and VST file (`VST/BisectionInit.v`); the C-order models
  and lemmas the VST files of a method share are in the AST-free `VST/<Method>.v`, and a spec's
  `kernel` lists its source files. A variant of a method, such as the `_unchecked` kernels, gets its
  own verification artifacts: those per source file, its own Flocq file, and its own
  `spec/<method>_unchecked.md` (IDs `<METHOD>-UNCHECKED-…`).
- **Comment and documentation:** keep in-code comments to a minimum. `doc/` is prose for human
  developers (what and why, short, with examples), indexed by `doc/README.md`; every exact
  technical detail (evaluation and check order, theorem coverage, tool quirks, CI internals,
  test-value derivations) is a note in `note/<topic>/` (format and rules in `note/README.md`);
  theorem lists and proof notes are in `spec/<method>.md`. Each `doc/` page ends with links to
  its notes. A method has its own `doc/api/<method>.md`; its test values are `test/` notes.
  `test/doc/` runs the `doc/api/` examples: a `c` block is a clang-format clean program followed
  by a `text` block of its output, a `python` block is a doctest session.
  `script/check_doc.py` checks note front matter, the generated note index (`--write` rewrites
  it), note ID references and every relative Markdown link; `script/dev.sh test` and CI
  `style_python` run it.
  ACSL `/*@ ... */` annotations are code, not comments. Python docstrings and CPython
  `tp_doc`/`ml_doc` strings stay (they are runtime API).
- **Spec:** one `spec/<method>.md` per method with YAML front matter listing theorem IDs prefixed with the method in capitals,
  `_` written as `-` (`BISECTION-A1`, `EULER-UNCHECKED-C1`, …), the `kernel` source file or list of files,
  layer (A real, B float, C code), informal statement, and the per-prover constant name. `script/check_spec.py`
  is the gate: every listed constant must exist, with axioms within the allowed list, and no `sorry`/`Admitted`.

## Toolchain pin

| Tool | Version | Note |
|---|---|---|
| Lean 4 | `leanprover/lean4:v4.35.0` | matches Mathlib `lean-toolchain`; `verification/lean/lean-toolchain` |
| Rocq | 9.2.0 | **not 9.3**: CompCert 3.18 opam caps `coq < 9.3~`. Homebrew `rocq 9.3` is unused; use the opam switch `4.14.1` |
| VST | 2.17 | with CompCert 3.18 (its `clightgen` reports 3.17) |
| Flocq | 4.2.2 | also in CI: `verify_rocq` opam-installs it with Coquelicot |
| Coquelicot | 3.4.5 | also in CI: `verify_rocq` opam-installs it on `mathcomp/mathcomp:2.6.0-rocq-prover-9.2` |
| Frama-C | 32.1 | local opam switch pinned (`opam pin add frama-c 32.1`) to match CI (`framac/frama-c:32.1`); WP with `-wp-rte -wp-model +float`; Alt-Ergo 2.6.4 |
| CMake | ≥ 3.25 | |
| Python | managed by `uv` (`.python-version`) | |
| clang-format | 23.1.3 | PyPI wheel in the uv `lint` group |

CompCert is under the INRIA non-commercial license: used for research only and never shipped. It exists
only in local opam switches; no CI job or container image contains it.

## Layout

```
include/diana/        public header             src/                verified kernel, callback wrapper
python/src/           Python package (pyproject.toml at root)
python/ext/           CPython extension         test/doc/           doc/api example
test/c/               ctest                     test/python/        pytest
test/install/         find_package consumer     spec/               theorem list per method
verification/lean/    Lake project              verification/rocq/  Real/ Float/ VST/
verification/clight/  committed clightgen out  test/benchmark/      timing driver
verification/frama-c/ WP goal count/session/cache
script/               check_spec, dev, frama_c   ci/docker/          prover image
.github/workflows/    GitHub Actions mirror of the GitLab jobs (.gitlab-ci.yml is primary)
doc/                  human docs: api/, development/, verification/ (trust, report)
note/                 technical notes per topic, index by topic and by path (README.md)
```

## How to run

- Everything below, in one script: `script/dev.sh config|build|test|verify` (`script/dev.sh help`; build
  directory `build`, Debug with sanitizers; `verify` needs the opam switch, runs the compiler
  comparison, the Lean build, the Rocq build and the WP rows at once after the Clight check with
  logs in `build/verify/`, `DIANA_JOB` jobs (default: the CPU count; `1` is the sequential path
  for debugging; the Rocq job count is also capped by memory, `doc/verification/local.md`), then
  runs the spec gate with `--strict` so an unproved listed theorem fails it, rewrites the report,
  and runs the provenance check)
- C: `cmake -S . -B build -DDIANA_BUILD_TEST=ON -DDIANA_WERROR=ON && cmake --build build && ctest --test-dir build`
  (`DIANA_BUILD_PYTHON` is ON by default and needs Python `Development.Module`; add
  `-DDIANA_BUILD_PYTHON=OFF` for a C-only build, as the C-only CI jobs do)
- C format: `uv sync --group lint && git ls-files '*.c' '*.h' | xargs uv run clang-format -i` (`--dry-run --Werror` to check)
- Python: `uv sync --group test --group lint && uv run pytest && uv run ruff check python` (the `pyproject.toml` is at the repo root so the sdist can carry the C sources; package code lives in `python/src/diana`)
- Wheel: `uv run script/check_wheel.py` builds and checks static and shared installed wheels
  (`DIANA_BUILD_SHARED_LIB`, not the generic `BUILD_SHARED_LIBS`); shared wheels bundle an
  unversioned runtime beside the extension. Standalone CMake builds retain library versioning and
  respect `CMAKE_INSTALL_INCLUDEDIR` in the exported target. Linux and macOS only, no Windows
  branch anywhere. Sanitized installations export their runtime link options; macOS install tests
  inherit the architecture list, SDK, and deployment target.
- Benchmark: `script/benchmark.sh [cc...]` builds Release with each compiler and times the checked
  against the unchecked kernels (`test/benchmark/unchecked.c`); the figures in the docs are its output
  (`doc/development/benchmark.md`), so re-run it and update them together
- Coverage: `uv sync --group test --group coverage && uv run pytest --cov=diana`; C and extension coverage via gcovr as in the `coverage_c`/`coverage_python` CI jobs
- Lean: `cd verification/lean && lake exe cache get && lake build` (Mathlib pinned by `lake-manifest.json`)
- Rocq: `cd verification/rocq && make -j4 && make check` (inside the opam switch, see `CONTRIBUTING.md`;
  `-j` is passed through to the generated makefile). `make real` (layer A) and `make float`
  (layers A and B) take their files from `_CoqProject` and need no CompCert or VST; CI
  `verify_rocq` runs `make float` and the spec gate `--prover rocq --layer A --layer B`.
  Layer C-VST, its Rocq axiom gate, and the Clight AST are checked **only locally**; run the
  steps in `doc/verification/local.md` before committing a change to `src/`,
  `include/`, `verification/`, `spec/`, `script/axiom_allow.yaml` or `script/run_frama_c.sh`
- Frama-C: `script/verify_frama_c.sh` (runs `script/run_frama_c.sh` and `script/check_frama_c.sh`
  for every `<source> <goal-count>` row of `verification/frama-c/expectation.txt`, `DIANA_JOB`
  rows at a time, each row in its own `verification/frama-c/session/<row>` and `cache/<row>`,
  one `report.txt` in row order; all goals must prove and each count must match;
  `script/dev.sh verify` and CI both call it)
- Clight regeneration: `clightgen -normalize -Iinclude -Isrc -o verification/clight/<kernel>_aarch64_macos.v src/<kernel>.c` (today `bisection_init`, `bisection_mid`, `bisection_result`, `bisection_step`, `cholesky`, `euler_step`, `euler_step_unchecked`, `forward_substitution`, `fp_sqrt`, `lu`, `lu_solve`, `newton_init`, `newton_result`, `newton_step`, `rk4_stage`, `rk4_stage_unchecked`, `rk4_step`, `rk4_step_unchecked`, `simpson`, `transpose_substitution` and `trapezoidal`) **on AArch64 macOS only** (the AST is named after its CompCert target, `<kernel>_<arch>_<system>.v`; never overwrite it from another platform), after a change to the kernel or a header it includes, then `make` in `verification/rocq`; committed, not regenerated in CI. `script/dev.sh verify` checks the ASTs of the current target and skips the others, then records the hash of each AST, its source and every header it includes from `include/` or `src/` in `verification/clight/manifest.txt` (note VST-009); commit it with the AST
- Compiler comparison: `opam exec -- script/compare_compiler.sh` builds `src/*.c` with the corpus
  driver `test/c/test_compiler.c` once with `ccomp` and with each gcc/clang found
  (`DIANA_COMPARE_CC` to choose) at `-O0`/`-O2`/`-O3`, and fails on any byte of difference in the
  printed bit patterns; `script/dev.sh verify` runs it and skips it without `ccomp`; local only.
  On macOS it sets an unset `MACOSX_DEPLOYMENT_TARGET` from `sw_vers` (GCC 13 cannot build without it).
  Keep the driver's arrays static: CompCert 3.17 on AArch64 macOS misaligns `sp` in a `main`
  frame over about 500 bytes (`SIGBUS`), and inlining moves callee locals into `main`
- Provenance check: `uv run script/check_provenance.py` (standard library and git, no prover)
  fails when a committed Clight AST, its source or a header differs from
  `verification/clight/manifest.txt`, when the report stamp differs from the tree, or when a report
  cell is not `ok`; `script/dev.sh verify` runs it last and CI runs it in `verify_provenance`
  (stage `verify`, note CI-016), so a change to a stamped input needs a local verify run whose
  manifest and report are committed
- Doc check: `uv run script/check_doc.py` (`--write` regenerates the index of `note/README.md`)
- Spec gate: `uv run script/check_spec.py --run --strict` (runs both provers' check files, `--prover lean|rocq` to select one, `--layer A|B|C` (repeatable) to check only those layers; a run of both provers on every layer rewrites the generated report `doc/verification/report.md`, stamped with the SHA-256 of `include/`, `spec/`, `src/`, `verification/`, `script/axiom_allow.yaml` and `script/run_frama_c.sh` and the tool versions (note GATE-009), a partial or structural run leaves it alone; commit it, CI does not regenerate it; `--no-report` to leave it alone on a full run)
  The default full strict gate also requires a unique positive Frama-C expectation count for the
  `acsl` file of each ACSL theorem; fresh WP execution and report checking remain in `script/dev.sh verify`.
  Lean CI uses `--run --strict --prover lean --no-report`, so missing Lean proofs fail the gate
  without requiring Rocq-only layers or Frama-C coverage; Rocq CI uses
  `--run --strict --prover rocq --layer A --layer B --no-report` (note CI-013).
- CI: GitLab CI (`.gitlab-ci.yml`) is primary and alone makes a release. The GitHub mirror runs
  `.github/workflows/ci.yml` on every push, with the GitLab job names, `needs`, images (pinned by
  digest) and commands, plus macOS jobs and `test_python` on Python 3.12, 3.13 and 3.14, and
  `style_git.yml`; its `change` job selects jobs from the `.change_*` lists of `.gitlab-ci.yml`
  (`script/ci_change.py`), so a list is edited in one place; caches keyed on their inputs; actions
  pinned to commit SHAs, `permissions: contents: read` (`doc/development/ci.md`, notes CI-017 to
  CI-026)

## Status

Current state only; history is `CHANGELOG.md`. The theorem status, WP goal counts and tool
versions of the last local run are in the generated `doc/verification/report.md`, the source of
truth: never copy its figures here. Theorems and proof notes per method: `spec/<method>.md`.

Every method is proved through every layer: A in Lean and Rocq, B in Flocq, C by Frama-C WP and
by VST against the Flocq model.

| Method | Kernel | Spec |
|---|---|---|
| Bisection | `diana_bisection_init`/`step`/`result`, helper `diana_bisection_mid` | `bisection` |
| Newton | `diana_newton_init`/`step`/`result` | `newton` |
| Trapezoidal, Simpson | `diana_trapezoidal`, `diana_simpson` | `trapezoidal`, `simpson` |
| Euler, RK4 | `diana_euler_step`, `diana_rk4_stage`, `diana_rk4_step` | `euler`, `rk4` |
| Cholesky | `diana_cholesky`, helper `diana_fp_sqrt` | `cholesky` |
| Substitution | `diana_forward_substitution`, `diana_transpose_substitution` | `substitution` |
| LU | `diana_lu`, `diana_lu_solve` | `lu`, `lu_solve` |

The opt-in `_unchecked` Euler and RK4 kernels have layers B and C only (`euler_unchecked`,
`rk4_unchecked`). The callback wrappers and the Python binding are tested, not verified.

Layer C-VST, its Rocq axiom gate, the Clight AST check and the `ccomp` comparison run only locally
(note VERIFY-001); CI builds layers A and B and runs their Rocq axiom gate, runs WP, and
`verify_provenance` checks only that the committed report and AST manifest match the sources. What
each layer assumes: `doc/verification/trust.md`.

Version 1.0.0 is set everywhere (note BUILD-006) and its `CHANGELOG.md` section is dated, but the
`v1.0.0` tag is held: create it only on an explicit request (CI `release` runs only on a version
tag, note CI-014).
