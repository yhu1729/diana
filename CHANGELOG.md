# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Python binding `diana.simpson(y, h)` (driver `diana._simpson`), with the buffer handling of
  `diana.trapezoidal`: it raises `TypeError` for another element type, and `ValueError` for another
  layout, fewer than three samples, an even number of samples, or a non-finite result.
  `test/python/test_simpson.py` checks the buffer handling, bitwise agreement with a sequential
  binary64 evaluation (Hypothesis), the SIMPSON-B2 rounding bound against exact rational
  arithmetic, and fourth-order convergence against mpmath.
- VST proves SIMPSON-C2 (`Diana.VST.Simpson.body_diana_simpson`) against the committed AArch64
  macOS Clight AST `verification/clight/simpson_aarch64_macos.v`: for non-NULL `y` with an odd
  `n >= 3`, `diana_simpson` returns `DIANA_OK` and writes the Flocq model value exactly when it is
  finite, and otherwise returns `DIANA_ERR_ARG` with `*result` unchanged. Every Simpson theorem is
  now proved, so the full strict spec gate passes with both quadrature rules.
- Flocq proves the Simpson binary64 theorems in `verification/rocq/theory/Float/Simpson.v`:
  SIMPSON-B1 (`finite_result`: a finite result implies finite `h`, samples and partial sums) and
  SIMPSON-B2 (`forward_error`: `|r − h·S′/3| ≤ γₚ₊₅·|h|·A/3 + (1 + u)·η/3 + η` for `(p + 5)·u < 1`,
  with `A` the Simpson-weighted absolute sum of the samples). `Diana.Float.Sum` gains `fdiv` with
  its value and finiteness lemmas, exact scaling by a power of two (`fmul_exact`), `gamma_mono`,
  and the addition step `add_step`; `fold_error` takes its absolute error term as a parameter, so
  a sum started from an exact `+0` carries none.
- Lean and Rocq prove the Simpson error bounds SIMPSON-A1 (`Diana.Real.Simpson.local_error`, one
  double panel: `M₄·h⁵/90`) and SIMPSON-A2 (`composite_error`, `2p` panels:
  `(b − a)·h⁴·M₄/180`) for `f` with a two-sided fourth derivative bounded by `M₄` on the interval;
  `f⁗` need not be continuous. Both reuse `Diana.Real.Quadrature`, and `make real` builds the Rocq
  proof.
- Composite Simpson rule over tabulated samples, `diana_simpson(y, n, h, result)` in
  `diana/simpson.h`, for an odd `n >= 3`: the odd and even interior samples are summed separately,
  left to right from `+0`, and the result is `(h * ((y[0] + y[n-1]) + 4 * so + 2 * se)) / 3`. It
  returns `DIANA_ERR_ARG` without writing `*result` for NULL pointers, `n < 3`, an even `n`, or a
  non-finite result. Frama-C WP proves its ACSL contract (58 goals, SIMPSON-C1);
  `spec/simpson.md` fixes the operation order and lists the planned layer-A, layer-B and VST
  theorems. `test/c/test_simpson.c` covers every path of the kernel: argument errors, exact results
  on cubic data, the operation order, overflow in each operation, NaN and infinite samples and
  `h`, `h = 0`, and underflow to zero.
- `script/check_commit.sh` checks commit history against the commit convention: no merge commit,
  a `<type>[(scope)]: <summary>` subject of at most 50 characters without an article, a message
  that is the subject and one `Signed-off-by` matching the committer, and an author date equal to
  the commit date. The new `pre-push` hook in `.git-hooks/` runs it on the commits the remote does
  not have, and the `style_git` CI job on the commits since the branch's previous pipeline (the
  merge request's commits in a merge request pipeline, otherwise the whole history when there is
  no previous pipeline).
- Composite trapezoidal rule over tabulated samples, `diana_trapezoidal(y, n, h, result)` in
  `diana/trapezoidal.h`. It returns `DIANA_ERR_ARG` without writing `*result` for NULL
  pointers, `n < 2`, or a non-finite result. Frama-C WP proves its ACSL contract (41 goals,
  TRAPEZOIDAL-C1); `spec/trapezoidal.md` lists the layer-A error bounds, the Flocq
  finiteness and forward-error theorems, and the VST theorem.
- Python binding `diana.trapezoidal(y, h)` (driver `diana._trapezoidal`). It reads a
  one-dimensional, C-contiguous, aligned buffer of native float64 in place through the buffer
  protocol, with no NumPy dependency, and copies any other iterable of numbers into an
  `array.array("d")`. It raises `TypeError` for another element type, and `ValueError` for another
  layout, fewer than two samples, or a non-finite result.
- `test/c/test_trapezoidal.c` covers every path of `diana_trapezoidal`, restoring 100% C line and
  branch coverage: NULL pointers, `n < 2`, exact results on affine data, the left-to-right
  summation order, overflow from finite samples, NaN and infinite samples and `h`, `h = 0`, and
  underflow to zero. `test/python/test_trapezoidal.py` checks the binding's buffer handling,
  bitwise agreement with a sequential binary64 evaluation (Hypothesis), the forward rounding-error
  bound against exact rational arithmetic, and second-order convergence against mpmath.
- Lean and Rocq prove the trapezoidal error bounds TRAPEZOIDAL-A1
  (`Diana.Real.Trapezoidal.local_error`, one panel: `M₂·h³/12`) and TRAPEZOIDAL-A2
  (`composite_error`, `m` panels: `(b − a)·h²·M₂/12`) for `f` with a two-sided second derivative
  bounded by `M₂` on the interval; `f″` need not be continuous. The Rocq proof is the first to use
  Coquelicot (`RInt`, `is_derive`); `make real` and the `verify_rocq` CI job compile it.
- Flocq proves the trapezoidal binary64 theorems in `verification/rocq/theory/Float/Trapezoidal.v`:
  TRAPEZOIDAL-B1 (`finite_result`: a finite result implies finite `h`, samples and partial
  sums, so no operation overflowed) and TRAPEZOIDAL-B2 (`forward_error`:
  `|r − T| ≤ γₙ·|h|·A + (1 + γₙ₋₁)·|h|·η + η` for `n·u < 1`, with `A` the trapezoid-weighted
  absolute sum of the samples and `η = 2⁻¹⁰⁷⁵`).
- VST proves TRAPEZOIDAL-C2 (`Diana.VST.Trapezoidal.body_diana_trapezoidal`) against the committed
  AArch64 macOS Clight AST `verification/clight/trapezoidal_aarch64_macos.v`: for non-NULL `y` with
  `n >= 2`, `diana_trapezoidal` returns `DIANA_OK` and writes the Flocq model value exactly when
  it is finite, and otherwise returns `DIANA_ERR_ARG` with `*result` unchanged. Every trapezoidal
  theorem is now proved, so the full strict spec gate passes.
- `script/check_wheel.py` checks static and shared installed wheels in isolated environments;
  Python CI runs it. `test_install` checks the installed CMake consumer with a custom
  header directory and with a shared library, and gates releases.
- `test/c/test_bisection.c` covers the last uncovered paths of the kernel and the wrapper, taking C
  line and branch coverage to 100%: the `diana_bisection_init` early `DIANA_OK` (bracket already
  within the tolerance, and a bracket so narrow that the midpoint rounds onto an endpoint, in both
  rounding directions), the `diana_bisection_step` stagnation exits on each side of the bracket
  update, a non-finite `fb`, and in `diana_bisection` a callback that returns a non-finite value at
  the midpoint plus the `iter == NULL` calls.

### Changed

- The buffer checks of the array kernels' Python bindings are one helper,
  `diana_py_get_samples` in `python/ext/convert.c`, with the same checks, order and messages that
  `diana.trapezoidal` had.
- The reusable parts of the trapezoidal proofs are separate modules, with the theorem statements
  unchanged: `Diana.Real.Quadrature` in Lean and Rocq (the mean-value bound against a boundary
  function, the clamped extension used for the fundamental theorem of calculus, and the sum of
  per-panel errors, `panel_error`) and `Diana.Float.Sum` in Rocq (`u`, `η`, `γₖ`, the rounding
  error lemmas, and the recursive-summation bound `fold_error`). `make real` builds
  `Real/Quadrature.v` before `Real/Trapezoidal.v`.
- The bisection C API is named after the method (`bisect` in v0.1.0, a breaking change):
  `diana/bisection.h` declares `diana_bisection_state`, `diana_bisection_init`,
  `diana_bisection_step` and `diana_bisection_result`, the callback wrapper is `diana_bisection`
  with `diana_bisection_fn`, and the kernel is `src/bisection.c`.
- The Python bisection API follows: the driver is `diana.bisection` (module `diana._bisection`)
  and the reverse-communication state is `diana.Bisection` (`diana.bisect` and `diana.Bisect`
  in v0.1.0).
- The bisection proofs are renamed to match: Rocq modules `Diana.Real.Bisection`,
  `Diana.Float.Bisection` and `Diana.VST.Bisection`, the Clight AST
  `verification/clight/bisection_aarch64_macos.v`, regenerated from `src/bisection.c`, and the
  Lean namespace `Diana.Real.Bisection`.
- The bisection spec is `spec/bisection.md`, and its theorem IDs are `BISECTION-A1` to
  `BISECTION-C5` (`spec/bisect.md` and `BIS-*` in v0.1.0).
- The spec gate requires each theorem ID to start with its method in capitals (`BISECTION-A1` in
  `spec/bisection.md`) and no longer caps that prefix at six letters.
- `verify_rocq` runs on `mathcomp/mathcomp:2.6.0-rocq-prover-9.2` and installs Coquelicot 3.4.5,
  so layer-A Rocq proofs can use Coquelicot integrals and derivatives in CI.
- Frama-C verification data lives in `verification/frama-c/`, with all expected goal counts in
  `expectation.txt`, one `<source> <goal-count>` row per verified C file; the spec gate matches
  each ACSL theorem by its `acsl` file. Script filenames and identifiers use `frama_c`; CI, the local
  verification workflow, and the spec report read the consolidated baseline.
- `CONTRIBUTING.md` is rewritten: a quick-start sequence, the project conventions, a "Before you
  commit" section separating what CI checks from the local-only proof layers, and a section on
  proposing a change. `README.md` gained a "Contribute" section pointing at it.
- The project name is styled `Diana` in prose; lowercase `diana` stays only where it is an
  identifier (package, CMake target, library file, URL).
- `script/dev.sh verify` runs the spec gate with `--strict`, so it fails on a theorem listed in
  `spec/` that no prover proves (`missing`), not only on a disallowed axiom. Lean CI also uses
  `--strict`, with `--prover lean` limiting its checks to Lean proofs.

### Fixed

- `script/run_frama_c.sh` passes a `SKIP` entry to `-wp-skip-fct` only for sources that name it,
  so WP runs on a kernel without the bisection helper instead of rejecting the option.
- Sanitized CMake installations propagate sanitizer runtime link requirements to consumers.
- Installed-consumer tests preserve macOS architecture lists, SDKs, and deployment targets.
- Standalone Windows shared libraries export the public C functions, as wheel builds already did.
- The full strict spec gate rejects ACSL specifications with missing, duplicate, or invalid
  Frama-C expectation entries.
- `script/dev.sh verify` runs WP for the last `expectation.txt` row even without a trailing
  newline.
- `verify_frama_c` runs WP for every `expectation.txt` row through `script/verify_frama_c.sh`,
  the loop `script/dev.sh verify` uses, instead of only `src/bisection.c`, and uploads only one
  consolidated `verification/frama-c/report.txt` instead of a report per kernel and the unused
  WP session directory.
- Python `Bisection` objects allocated without successful initialization reject `step()` and
  `result()` instead of reporting a successful zero-valued result.
- C and Python coverage jobs run on every default-branch pipeline, keeping the README coverage
  badges populated after changes outside their path filters.
- Shared Python wheels bundle an unversioned `libdiana` runtime beside the extension and locate
  it without the build tree or loader-path overrides. Static wheels and standalone CMake library
  versioning are unchanged.
- The exported CMake target uses `CMAKE_INSTALL_INCLUDEDIR`, matching the header installation
  destination when a custom include directory is selected.
- Missing listed Lean proofs now fail CI instead of passing the non-strict spec gate.
- `script/check_spec.py` parses Rocq's `Print Assumptions` output from stdout only and rejects
  output it cannot account for (wrong block count, empty `Axioms:` block, unindented non-axiom
  line) as `check failed`. Axiom names are taken as whole tokens, so a Unicode name survives.
- `verification/rocq/Makefile` gained the `check` target that `script/check_spec.py` and the
  documentation already assumed, so `script/dev.sh verify` reaches the end of the spec gate instead
  of reporting every Rocq theorem as `check failed`. `check` compiles the generated `CheckSpec.v`
  with the `_CoqProject` load paths (the file is deliberately not listed there), and `clean` now
  removes its artifacts.

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
- `script/dev.sh config|build|test|verify` for the whole local loop, `script/run_frama_c.sh` and
  `script/check_frama_c.sh` for WP (the latter is the gate: WP does not set a non-zero exit status
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
  and is never shipped, and Alt-Ergo is only a proof oracle. Diana itself has no runtime
  dependency.

[Unreleased]: https://gitlab.com/yhu1729/diana/-/compare/v0.1.0...main
[0.1.0]: https://gitlab.com/yhu1729/diana/-/tags/v0.1.0
