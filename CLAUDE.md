# Diana

Formally verified numerical method library in C11 with a hand-written CPython extension. The
mathematical specification is proven in both Lean 4 (Mathlib) and Rocq (Stdlib reals; Coquelicot
where integrals and derivatives are needed); floating-point bounds in Rocq (Flocq); C-code
correctness in Rocq (VST via CompCert `clightgen`) and Frama-C (WP).
Trust statement and generated theorem report: `doc/verification.md`.
API: `doc/api.md`. Build, test, and CI rationale: `doc/development.md`.

## Convention

- **Name:** single-form noun and base-form verb everywhere: directory (`test/`, `verification/`, `script/`,
  `doc/`, `wrapper/`), identifier (`diana_bisection_init`, `check_spec`), CI job (`build`, `test`),
  Python API (`diana.bisection`). No plural, no `-ing`/`-s` verb form.
  - **Project name:** `Diana` in prose (heading, documentation sentence, user-facing string);
    lowercase `diana` only where it is an identifier (package, CMake target, library file, URL).
- **Commit:** `git commit -s` (Signed-off-by) always. Conventional Commits; the `commit-msg` hook accepts
  type `feat fix perf refactor build style test ci doc chore` (note `doc`, not `docs`). Never `--no-verify`.
  No push, tag, or merge request without an explicit request.
  - **Message:** subject line only — no body, no `Co-Authored-By` or other trailer, just the
    `Signed-off-by` line `-s` adds. Keep the subject short (~50 characters); drop articles
    (`add bisect header`, not `add the bisection header`) and name the thing, not the reason.
  - **Size:** one logical step per commit, usually one file (a header, a kernel, a test, a doc), at
    most a handful when they only make sense together (a `.c` with the `CMakeLists.txt` line that
    builds it). Split a change that touches the library, its test and its doc into one commit each.
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
- **Python binding:** C extension sources in `python/ext/` (`module.c` creates `diana._diana` and calls one
  `diana_py_<kernel>_exec` per file; shared helpers in `module.h`); pure-Python package in `python/src/diana/`
  with one private driver module per kernel (`_bisection.py`) re-exported by `__init__.py`.
  `Bisection` starts with status `ERR_ARG` until initialization succeeds; `step` and `result` reject
  uninitialized objects, and a failed reinitialization preserves the previous state.
- **ACSL:** arithmetic on doubles is exact real arithmetic, write rounded values with casts
  `(double)(...)`; no hexadecimal float literal anywhere in ACSL (WP 33.0 rejects them in lemmas and
  mistranslates them in predicates), use exact integer expressions such as `((1 << 53) - 1) << 970`;
  a float fact that WP cannot prove goes into a small static helper whose contract is listed in
  `SKIP` of `script/run_frama_c.sh` and proved in Flocq. That skip list is the trust boundary between
  Frama-C and Rocq; every entry needs a `BIS-B*`-style theorem.
- **Verified kernel shape:** reverse communication. A kernel is a pure state machine on a caller-owned
  struct (`init` / `step` / `result`) or a function over tabulated arrays. No function pointer in a
  verified kernel. Callback convenience wrappers live in `src/wrapper/` and are not VST-verified.
- **Comment:** keep in-code comments to a minimum. Rationale, API description, and proof notes go
  in `doc/` (`api.md`, `development.md`, `verification.md`) or `spec/<method>.md`. ACSL `/*@ ... */`
  annotations are code, not comments. Python docstrings and CPython `tp_doc`/`ml_doc` strings stay
  (they are runtime API).
- **Spec:** one `spec/<method>.md` per method with YAML front matter listing theorem IDs (`BIS-A1`, …),
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
python/ext/           CPython extension
test/c/               ctest                     test/python/        pytest
test/install/         find_package consumer
test/reference/       mpmath data (planned)     spec/               theorem list per method
verification/lean/    Lake project              verification/rocq/  Real/ Float/ VST/
verification/clight/  committed clightgen out
verification/frama-c/ WP goal count/session/cache
script/               check_spec, dev, frama_c   ci/docker/          prover image
doc/                  api, development, verification (trust statement + generated report)
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
- Wheel: `uv run script/check_wheel.py` builds and checks static and shared installed wheels;
  shared wheels bundle an unversioned runtime beside the extension. Standalone CMake builds
  retain library versioning and respect `CMAKE_INSTALL_INCLUDEDIR` in the exported target.
  Shared Windows builds export the C API in both modes. Sanitized installations export their
  runtime link options; macOS install tests inherit the architecture list, SDK, and deployment target.
- Coverage: `uv sync --group test --group coverage && uv run pytest --cov=diana`; C and extension coverage via gcovr as in the `coverage_c`/`coverage_python` CI jobs
- Lean: `cd verification/lean && lake exe cache get && lake build` (Mathlib pinned by `lake-manifest.json`)
- Rocq: `cd verification/rocq && make && make check` (inside the opam switch, see `CONTRIBUTING.md`).
  Layers B and C-VST, the Rocq axiom gate, and the Clight AST are checked **only locally**; run the
  steps in `doc/development.md` (Local verification) before committing a change to `src/`,
  `include/`, `verification/`, or `spec/`
- Frama-C: `script/verify_frama_c.sh` (runs `script/run_frama_c.sh` and `script/check_frama_c.sh`
  for every `<source> <goal-count>` row of `verification/frama-c/expectation.txt`; all goals must
  prove and each count must match; `script/dev.sh verify` and CI both call it)
- Clight regeneration: `clightgen -normalize -Iinclude -Isrc -o verification/clight/bisection_aarch64_macos.v src/bisection.c` **on AArch64 macOS only** (the AST is named after its CompCert target, `<kernel>_<arch>_<system>.v`; never overwrite it from another platform), after a change to the kernel or a header it includes, then `make` in `verification/rocq`; committed, not checked in CI. `script/dev.sh verify` checks the ASTs of the current target and skips the others
- Spec gate: `uv run script/check_spec.py --run --strict` (runs both provers' check files, `--prover lean|rocq` to select one and rewrites the generated report at the end of `doc/verification.md`; commit it, CI does not regenerate it; `--no-report` to leave it alone)
  The default full strict gate also requires a unique positive Frama-C expectation count for the
  `acsl` file of each ACSL theorem; fresh WP execution and report checking remain in `script/dev.sh verify`.
  Lean CI uses `--run --strict --prover lean --no-report`, so missing Lean proofs fail the gate
  without requiring Rocq-only layers or Frama-C coverage.

## Status

See `CHANGELOG.md`. v0.1.0: scaffolding and bisection end-to-end. Layers A and B are complete for the kernel, Frama-C WP proves all 162 goals, and VST covers `bisection_mid`, the `src/fp.h` helpers and `diana_bisection_result`; VST for `diana_bisection_init`/`diana_bisection_step` is deferred. M1 (trapezoid, Simpson, Euler) has started: `diana_trapezoid` (tabulated, C only) with its ACSL contract proved by WP (41 goals) and `spec/trapezoid.md`; its layer A, B and VST proofs are not written yet, so the strict spec gate (and Lean CI) fails on TRAP-A1/A2 until they are.
