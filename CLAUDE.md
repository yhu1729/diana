# Diana

Formally verified numerical method library in C11 with a hand-written CPython extension. The
mathematical specification is proven in both Lean 4 (Mathlib) and Rocq (Stdlib reals; Coquelicot
where integrals and derivatives are needed); floating-point bounds in Rocq (Flocq); C-code
correctness in Rocq (VST via CompCert `clightgen`) and Frama-C (WP).
Documentation index: `doc/README.md`. Trust statement: `doc/verification/trust.md`; generated
theorem report: `doc/verification/report.md`. API: `doc/api/`. Build and CI rationale:
`doc/development/`; test values: `doc/test/`. Future work: `doc/roadmap.md`, one line per idea,
no design (a design is written only when an item is picked up).

## Convention

- **Name:** single-form noun and base-form verb everywhere: directory (`test/`, `verification/`, `script/`,
  `doc/`, `wrapper/`), identifier (`diana_bisection_init`, `check_spec`), CI job (`build`, `test`),
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
    commits since the branch's previous pipeline. Link both hooks once per clone (`CONTRIBUTING.md`).
- **Living document:** update `CHANGELOG.md` (`Unreleased` section, Keep a Changelog) and this file in the
  same commit as any change that affects them.
- **Python:** `uv` manages the interpreter and environment (`uv sync` at the repo root; `.python-version`
  and `uv.lock` are committed). Never `pip` directly, never the system Python.
- **C:** C11, `-Wall -Wextra -Wconversion -Wshadow -Wvla -pedantic -Werror` (`-Werror` is the CMake option
  `DIANA_WERROR`, OFF by default so end-user builds survive new compiler warnings; CI and `script/dev.sh`
  turn it ON); no `malloc` and **no libm
  call** in a verified kernel (use `src/fp.h`: `diana_fp_finite`, `diana_fp_abs`; every external call
  would need an axiom in VST and Frama-C, and clightgen cannot parse macOS `<math.h>`); caller-owned
  buffer; every public function returns `diana_status`; prefix `diana_`; `-ffp-contract=off`, no
  `-ffast-math`/`-Ofast` (the verified semantics are strict IEEE binary64). Format with `clang-format`
  (LLVM style, `.clang-format`; use the version pinned in the uv `lint` group, CI `style_c` checks it).
- **Floating-point environment:** every numerical call requires nearest-even rounding, gradual
  underflow (no flush-to-zero or denormals-are-zero mode), and disabled traps on the calling
  thread. Diana does not check or change these settings; callbacks must preserve them. Compiler
  flags alone do not establish them (`doc/api/overview.md`).
- **Python binding:** C extension sources in `python/ext/` (`module.c` creates `diana._diana` and calls one
  `diana_py_<kernel>_exec` per file; shared helpers in `module.h`); pure-Python package in `python/src/diana/`
  with one private driver module per kernel (`_bisection.py`, `_newton.py`) re-exported by `__init__.py`, and
  `_convert.py` (`real`, the scalar check the drivers share: a string is rejected as the C `d`
  converter rejects it).
  `Bisection` and `Newton` start with status `ERR_ARG` until initialization succeeds; `step` and `result` reject
  uninitialized objects, and a failed reinitialization preserves the previous state. `Newton` takes `tol`
  without a default (no parameter-free stopping rule; `tol = 0` commonly ends in a two-cycle of adjacent doubles).
  An array kernel reads a buffer in place (`PyBUF_RECORDS_RO`; native float64, one-dimensional,
  C-contiguous, aligned, checked in the extension by `diana_py_get_samples` in `python/ext/convert.c`) and its driver copies any non-buffer iterable
  into `array.array("d")`; no NumPy in the package, only in tests.
- **ACSL:** arithmetic on doubles is exact real arithmetic, write rounded values with casts
  `(double)(...)`; no hexadecimal float literal anywhere in ACSL (WP 33.0 rejects them in lemmas and
  mistranslates them in predicates), use exact integer expressions such as `((1 << 53) - 1) << 970`;
  a float fact that WP cannot prove goes into a small static helper whose contract is listed in
  `SKIP` of `script/run_frama_c.sh` and proved in Flocq. That skip list is the trust boundary between
  Frama-C and Rocq; every entry needs a `BISECTION-B*`-style theorem.
- **Verified kernel shape:** reverse communication. A kernel is a pure state machine on a caller-owned
  struct (`init` / `step` / `result`) or a function over tabulated arrays. No function pointer in a
  verified kernel. Callback convenience wrappers live in `src/wrapper/` and are not VST-verified.
- **Comment:** keep in-code comments to a minimum. Rationale, API description, and proof notes go
  in `doc/` (`api/`, `development/`, `test/`, `verification/`, indexed by `doc/README.md`) or
  `spec/<method>.md`. A method has its own `doc/api/<method>.md` and `doc/test/<method>.md`;
  `test/doc/` runs the `doc/api/` examples: a `c` block is a clang-format clean program followed
  by a `text` block of its output, a `python` block is a doctest session.
  ACSL `/*@ ... */` annotations are code, not comments. Python docstrings and CPython
  `tp_doc`/`ml_doc` strings stay (they are runtime API).
- **Spec:** one `spec/<method>.md` per method with YAML front matter listing theorem IDs prefixed with the method in capitals (`BISECTION-A1`, …),
  layer (A real, B float, C code), informal statement, and the per-prover constant name. `script/check_spec.py`
  is the gate: every listed constant must exist, with axioms within the allowed list, and no `sorry`/`Admitted`.

## Toolchain pin

| Tool | Version | Note |
|---|---|---|
| Lean 4 | `leanprover/lean4:v4.35.0` | matches Mathlib `lean-toolchain`; `verification/lean/lean-toolchain` |
| Rocq | 9.2.0 | **not 9.3**: CompCert 3.18 opam caps `coq < 9.3~`. Homebrew `rocq 9.3` is unused; use the opam switch `4.14.1` |
| VST | 2.17 | with CompCert 3.18 (its `clightgen` reports 3.17) |
| Flocq | 4.2.2 | |
| Coquelicot | 3.4.5 | also in CI: `verify_rocq` opam-installs it on `mathcomp/mathcomp:2.6.0-rocq-prover-9.2` |
| Frama-C | 33.0 local (opam), 32.1 in CI (`framac/frama-c:32.1`, no 33 image yet) | WP with `-wp-rte -wp-model +float`; Alt-Ergo 2.6.4 |
| CMake | ≥ 3.25 | |
| Python | managed by `uv` (`.python-version`) | |
| clang-format | 23.1.3 | PyPI wheel in the uv `lint` group |

CompCert is under the INRIA non-commercial license: used for research only and never shipped. It exists
only in local opam switches; no CI job or container image contains it.

## Layout

```
include/diana/        public header             src/                verified kernel
src/wrapper/          callback wrapper          python/src/         Python package (pyproject.toml at root)
python/ext/           CPython extension         test/doc/           doc/api example
test/c/               ctest                     test/python/        pytest
test/install/         find_package consumer     spec/               theorem list per method
verification/lean/    Lake project              verification/rocq/  Real/ Float/ VST/
verification/clight/  committed clightgen out
verification/frama-c/ WP goal count/session/cache
script/               check_spec, dev, frama_c   ci/docker/          prover image
doc/                  README index; api/, development/, test/, verification/ (trust, report)
```

## How to run

- Everything below, in one script: `script/dev.sh config|build|test|verify` (`script/dev.sh help`; build
  directory `build`, Debug with sanitizers; `verify` needs the opam switch, runs the spec gate with
  `--strict` so an unproved listed theorem fails it, and rewrites the report)
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
- Coverage: `uv sync --group test --group coverage && uv run pytest --cov=diana`; C and extension coverage via gcovr as in the `coverage_c`/`coverage_python` CI jobs
- Lean: `cd verification/lean && lake exe cache get && lake build` (Mathlib pinned by `lake-manifest.json`)
- Rocq: `cd verification/rocq && make && make check` (inside the opam switch, see `CONTRIBUTING.md`).
  Layers B and C-VST, the Rocq axiom gate, and the Clight AST are checked **only locally**; run the
  steps in `doc/verification/local.md` before committing a change to `src/`,
  `include/`, `verification/`, or `spec/`
- Frama-C: `script/verify_frama_c.sh` (runs `script/run_frama_c.sh` and `script/check_frama_c.sh`
  for every `<source> <goal-count>` row of `verification/frama-c/expectation.txt`; all goals must
  prove and each count must match; `script/dev.sh verify` and CI both call it)
- Clight regeneration: `clightgen -normalize -Iinclude -Isrc -o verification/clight/<kernel>_aarch64_macos.v src/<kernel>.c` (today `bisection`, `euler`, `newton`, `simpson` and `trapezoidal`) **on AArch64 macOS only** (the AST is named after its CompCert target, `<kernel>_<arch>_<system>.v`; never overwrite it from another platform), after a change to the kernel or a header it includes, then `make` in `verification/rocq`; committed, not checked in CI. `script/dev.sh verify` checks the ASTs of the current target and skips the others
- Compiler comparison: `opam exec -- script/compare_compiler.sh` builds `src/*.c` with the corpus
  driver `test/c/test_compiler.c` once with `ccomp` and with each gcc/clang found
  (`DIANA_COMPARE_CC` to choose) at `-O0`/`-O2`/`-O3`, and fails on any byte of difference in the
  printed bit patterns; `script/dev.sh verify` runs it and skips it without `ccomp`; local only.
  On macOS it sets an unset `MACOSX_DEPLOYMENT_TARGET` from `sw_vers` (GCC 13 cannot build without it).
  Keep the driver's arrays static: CompCert 3.17 on AArch64 macOS misaligns `sp` in a `main`
  frame over about 500 bytes (`SIGBUS`), and inlining moves callee locals into `main`
- Spec gate: `uv run script/check_spec.py --run --strict` (runs both provers' check files, `--prover lean|rocq` to select one; a run of both provers rewrites the generated report `doc/verification/report.md`, a partial or structural run leaves it alone; commit it, CI does not regenerate it; `--no-report` to leave it alone on a full run)
  The default full strict gate also requires a unique positive Frama-C expectation count for the
  `acsl` file of each ACSL theorem; fresh WP execution and report checking remain in `script/dev.sh verify`.
  Lean CI uses `--run --strict --prover lean --no-report`, so missing Lean proofs fail the gate
  without requiring Rocq-only layers or Frama-C coverage.

## Status

See `CHANGELOG.md`. v0.1.0: scaffolding and bisection end-to-end. Layers A and B are complete for the kernel, Frama-C WP proves all 162 goals, and VST covers `bisection_mid`, the `src/fp.h` helpers and `diana_bisection_result`; VST for `diana_bisection_init`/`diana_bisection_step` is deferred. v0.2.0 completes M1 (trapezoidal, Simpson, Euler): `diana_trapezoidal` (tabulated; C tests at 100% line and branch coverage; Python `diana.trapezoidal` over the buffer protocol) with its ACSL contract proved by WP (41 goals) and `spec/trapezoidal.md`; Lean and Rocq (Coquelicot) prove its layer A (TRAPEZOIDAL-A1/A2) and Flocq its layer B (TRAPEZOIDAL-B1/B2); VST proves the C against the Flocq model (TRAPEZOIDAL-C2, `trapezoidal_aarch64_macos.v`), so the full strict spec gate passes. Simpson follows the same path: `diana_simpson` (tabulated, odd `n >= 3`; C tests at 100% line and branch coverage; Python `diana.simpson` over the buffer protocol) with its ACSL contract proved by WP (58 goals) and `spec/simpson.md`; Lean and Rocq prove its layer A (SIMPSON-A1/A2), Flocq its layer B (SIMPSON-B1/B2), and VST the C against the Flocq model (SIMPSON-C2, `simpson_aarch64_macos.v`), so Simpson is proved through every layer and the full strict spec gate passes; Euler follows the same path through every layer: `diana_euler_step` (out of place, all buffers separate, two passes so `y_out` is untouched on error; C tests at 100% line and branch coverage) with its ACSL contract proved by WP (49 goals) and `spec/euler.md`, the unverified callback wrapper `diana_euler`, and Python `diana.euler_step` and `diana.euler`; Flocq proves its layer B (EULER-B1/B2) and VST the C against the Flocq model (EULER-C2, `euler_aarch64_macos.v`, the first VST proof that writes an array); Lean and Rocq prove its layer A (EULER-A1/A2) on the shared modules `Diana.Real.OneStep` (discrete Grönwall for one-step methods) and, in Rocq, `Diana.Real.Vector` (max norm over `nat → R`); the shared proof modules `Diana.Real.Quadrature` (Lean, Rocq) and `Diana.Float.Sum` (Rocq) hold the lemmas Simpson reuses from the trapezoidal proofs. v0.3.0 (release notes in `CHANGELOG.md`, not yet tagged): VST proves `diana_bisection_init` and `diana_bisection_step` against the C-order models `c_init`/`c_step` (BISECTION-C6/C7), `c_step` writes the Flocq `fstep` (C8), and `init` and every `DIANA_CONTINUE` step establish the layer-B invariant (C9/C10), so bisection is proved through every layer and every kernel function has a VST proof. Newton's method opens M2: `diana_newton_init`/`step`/`result` (reverse communication; `step` takes `f(x)` and `f'(x)`; a zero derivative is the new `DIANA_ERR_SINGULAR` (-4, Python `SingularError`, a `ValueError`; reserved for zero pivots in Cholesky and LU too) and an overflowing step `DIANA_ERR_ARG`, both with the state unchanged; C tests at 100% line and branch coverage), the unverified wrapper `diana_newton`, Python `diana.Newton`/`diana.newton` (`tol` required), WP proves its ACSL contract (103 goals, NEWTON-C1), Lean and Rocq its layer A (NEWTON-A1/A2, quadratic one-step bound and convergence), Flocq its layer B (NEWTON-B1 to B3, including the half-ulp meaning of the stagnation stop), and VST the C against the C-order models and the Flocq `fstep` (NEWTON-C2 to C5, `newton_aarch64_macos.v`).

The 0.3.0 release preparation also aligns the package, CMake, header and consumer versions,
specifies the runtime floating-point environment, and makes the extension stubs match the
read-only state fields and positional-only `step` arguments.
