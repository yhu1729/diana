# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-10-13

First release. The scaffolding, the proof pipeline, and the bisection kernel end-to-end through
all three verification layers. Bisection is the only numerical method provided.

Layers B and C-VST, the Rocq axiom gate and the Clight AST are checked **locally only** — CI covers
layer A and Frama-C. `doc/verification.md` is the trust statement and says where each layer runs
and what it assumes; its generated report gives the status of every theorem.

### Added

#### C library
- Bisection in reverse-communication form: `diana_bisect_init`, `diana_bisect_step`,
  `diana_bisect_result` over a caller-owned `diana_bisect_state`, with full ACSL contracts. No
  `malloc`, no libm call, no function pointer in the verified kernel; `libdiana` does not link
  libm, so static-library consumers do not inherit `-lm`.
- Callback wrapper `diana_bisect` (`diana_bisect_fn`) in `src/wrapper/`, outside the VST-verified
  core. It writes the current estimate to `*root` both on `DIANA_OK` and on `DIANA_ERR_MAXITER`,
  and `*iter` is 0 on every early return.
- `diana_status` with `diana_status_str`, `diana_version`, and the `DIANA_VERSION_MAJOR`/`MINOR`/
  `PATCH`/`STRING` macros (`include/diana/diana.h` is the umbrella header).
- `src/fp.h`: libm-free `diana_fp_finite` and `diana_fp_abs`, so a verified kernel has no external
  call to axiomatise and CompCert's `clightgen` can parse it on macOS.
- CMake ≥ 3.25 build: C11, strict warning set, strict IEEE binary64 flags (`-ffp-contract=off`, and
  a hard error on `-Ofast`/`-ffast-math`), `DIANA_BUILD_TEST`, `DIANA_SANITIZER`, `DIANA_WERROR`,
  `DIANA_BUILD_PYTHON`, `BUILD_SHARED_LIBS`. `DIANA_WERROR` is OFF by default so an end-user build
  survives new compiler warnings; CI and `script/dev.sh` turn it ON. `DIANA_SANITIZER` instruments
  the library and the tests with ASan/UBSan. `DIANA_BUILD_PYTHON` is ON by default so that
  `compile_commands.json` describes `python/ext/` and clang-tidy analyses the extension with the
  real Python include path; it needs Python `Development.Module`, so a C-only build (the C-only CI
  jobs, a machine without the Python headers) passes `-DDIANA_BUILD_PYTHON=OFF`. The extension is
  installed only under scikit-build, so `cmake --install` of the C library never carries it.
- `cmake --install` exports `dianaConfig.cmake`/`dianaConfigVersion.cmake`
  (`SameMinorVersion` while the major version is 0); ctest tests `install` and `find_package` build
  the consumer project in `test/install/` against an installed tree.

#### Python binding
- Package `diana` with the hand-written CPython extension `diana._diana`: the `Bisect` state object,
  the `diana.bisect` driver, `status_str`, `version`, `__version__`, and the `BracketError` /
  `MaxIterError` exceptions (`MaxIterError` carries `estimate`, `width`, `iter` and survives
  pickling). Built by scikit-build-core from the root `pyproject.toml`; `uv` manages the
  environment; pytest suite in `test/python/`.
- `diana.bisect` converts `a` and `b` to `float` before evaluating `f`, so the bracket signs belong
  to the binary64 endpoints the kernel brackets. `max_iter` must fit a C `unsigned int`
  (`OverflowError` otherwise, `ValueError` for 0), and `status_str` rejects codes outside the C
  `int` range.
- The default `max_iter` is 2100, which covers the `tol = 0` worst case of 2098 steps, so
  `MaxIterError` is not expected with default arguments.

#### Verification
- **Layer A (ℝ)** in both provers: BIS-A1 (bracket invariant and width bound) and BIS-A2 (root in
  the bracket, midpoint error) — Lean 4 with Mathlib (toolchain v4.35.0), and Rocq with the Stdlib
  reals (`IVT_interv`). Standard axioms only.
- **Layer B (binary64, Flocq)**: BIS-B1 the midpoint `0.5 * (a + b)` is finite and in `[a, b]` when
  `|a|, |b| <= DBL_MAX/2`; BIS-B2 one step of the binary64 state machine preserves the bracket
  invariant and nests the bracket; BIS-B3 with `tol = 0` the iteration stops once the endpoints are
  adjacent doubles; BIS-B4 termination, via the number of doubles the bracket spans strictly
  decreasing on every continuing step.
- **Layer C-VST** against the AArch64 macOS Clight AST: BIS-C1 `bisect_mid`, BIS-C3
  `diana_fp_finite`, BIS-C4 `diana_fp_abs`, BIS-C5 `diana_bisect_result`. `diana_fp_abs` is
  specified as the conditional negation the C performs, not `Float.abs`, because the C returns
  `-0.0` for `-0.0`.
- **Layer C-WP**: BIS-C2, all 162 goals of `src/bisect.c` proved by Frama-C WP (float model, RTE)
  with Alt-Ergo 2.6.4 — memory safety, absence of undefined behaviour, separation of outputs from
  the state, the bracket predicate preserved by `init`/`step`, and no state change when either
  reports an error. The only assumed contract is `bisect_mid`, discharged by BIS-B1.
- Spec gate `script/check_spec.py`: validates the `spec/*.md` front matter, generates
  `CheckSpec.lean`/`CheckSpec.v`, checks each theorem's printed axioms against
  `script/axiom_allow.yaml`, and rewrites the report at the end of `doc/verification.md`.
  `--prover lean|rocq` selects a prover, `--strict` also fails on theorems that are not proved.
- `spec/bisect.md` lists all 11 theorem IDs with their layer, informal statement and per-prover
  constant.

#### Tooling and documentation
- `script/dev.sh config|build|test|verify` for the whole local loop, `script/run_framac.sh` and
  `script/check_framac.sh` for WP (the latter is the gate: WP does not set a non-zero exit status
  for an unproved goal). `config` syncs the uv environment before `cmake` and pins
  `-DPython_EXECUTABLE` to `.venv`, so the compile database describes the interpreter the pytest
  suite runs against; the clang-tidy step of `test` fails with a clear message when that database
  has no `python/ext/` entry, since a missing entry would surface as spurious findings.
- GitLab CI with stages style → build → test → report → verify → release: ruff, `clang-format`, naming
  checks, gcc/clang Release and Debug+sanitizer builds, ctest, pytest, sdist/wheel with
  `twine check`, coverage (`coverage_c` and `coverage_python`, gcovr and pytest-cov publishing
  Cobertura reports), Frama-C WP, Lean, Rocq layer A, and a tag release gated on every test and
  verify job. Every image is public and stock — no CI image contains CompCert.
- `.clang-format` (LLVM style, with ACSL annotations and CPython header macros protected),
  `.clang-tidy` with scoped overrides for `python/ext/`, `test/c/` and `test/install/`, and
  `.editorconfig`.
- `doc/api.md` (C and Python API), `doc/development.md` (build, test, CI, local verification),
  `doc/verification.md` (trust statement and generated report), `doc/third-party.md` (every tool
  with its version and license), `CLAUDE.md` and `CONTRIBUTING.md`.
- `doc/third-party.md` states the two non-commercial license conditions and how this project meets
  them: CompCert (INRIA) is used only to generate and check the Clight AST in a local opam switch
  and is never shipped, and Alt-Ergo is only a proof oracle. `diana` itself has no runtime
  dependency.

[Unreleased]: https://gitlab.com/yhu1729/diana/-/compare/v0.1.0...main
[0.1.0]: https://gitlab.com/yhu1729/diana/-/tags/v0.1.0
