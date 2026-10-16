# Development notes

Rationale that used to live in code comments. How to run each tool is in `CLAUDE.md` and
`CONTRIBUTING.md`.

## Build

- `cmake/warning.cmake` (`diana_set_strict_flag`) applies the strict warning set and strict IEEE
  binary64 semantics to every Diana target. The verified semantics assume no FMA contraction, no
  fast-math, and SSE2 or AArch64 arithmetic.
- `DIANA_BUILD_PYTHON` is ON by default, so a plain `cmake -S . -B build` describes `python/ext/`
  in `compile_commands.json`; without it clang-tidy parses those files with a guessed command, fails
  to find `<Python.h>`, and reports a cascade of findings that are artefacts of the failed parse.
  It needs Python with `Development.Module` (`find_package(... REQUIRED)`), so a build on a machine
  with no Python headers passes `-DDIANA_BUILD_PYTHON=OFF`, as the C-only CI jobs do. The extension
  is installed only under scikit-build; `cmake --install` of the C library never carries it.
- scikit-build-core builds the CPython extension in-tree and sets `SKBUILD`, which forces
  `DIANA_BUILD_PYTHON=ON`. Static wheels carry only the extension module and the Python package.
  With `BUILD_SHARED_LIBS=ON`, the wheel also carries an unversioned `libdiana` runtime beside the
  extension, without headers, archives, import libraries, or CMake exports. Standalone CMake
  installations retain the library's `VERSION`/`SOVERSION`. The wheel extension uses an install
  RPATH of `@loader_path` on macOS and `$ORIGIN` on Linux; the macOS library has an `@rpath` install
  name. On Windows, shared libraries export their functions in both standalone and wheel builds;
  the wheel DLL is beside the extension, where CPython's loader searches for dependencies.
- `GNUInstallDirs` is loaded before configuring the target's installed include directory, so
  `CMAKE_INSTALL_INCLUDEDIR` controls both header installation and the exported include path.
- `DIANA_WERROR` (`-Werror`) is OFF by default, so building from the sdist with a newer compiler
  that adds a warning does not fail for an end user. CI turns it ON in every job that compiles (CMake
  `-DDIANA_WERROR=ON`, and `SKBUILD_CMAKE_DEFINE` for the uv jobs that build the extension), and so
  does `script/dev.sh` (`config` and the `uv sync` of `config`/`build`).
- `DIANA_SANITIZER` uses directory-wide `add_compile_options`, which only reach targets created
  after the call, so it comes before `add_library(diana)`. The required sanitizer runtime link
  options are public usage requirements of `diana::diana`, including its installed target.

## Format

`.clang-format` is LLVM style with `InsertBraces: true` (every `if`/`else`/`for`/`while` body is a
braced block) and three additions needed for the code to survive formatting:

- `CommentPragmas: '^@'` leaves ACSL annotations (`/*@ ... */`) untouched; LLVM would reflow them
  at 80 columns and drop the `@` continuation prefix.
- `StatementMacros` for `PyObject_HEAD`/`PyObject_VAR_HEAD`, and a `Macros` expansion of
  `PyVarObject_HEAD_INIT`: these CPython macros carry their own `;` or `,`, so without the hint the
  next member or designator is joined onto the same line.

The `clang-format` version is pinned in the uv `lint` group, so local runs and CI `style_c` agree.

`.editorconfig` carries the same conventions for editors, per file type: 2-space C, Rocq and Lean,
4-space Python, shell and CMake, tabs in `Makefile`. It sets no `max_line_length` for C, because
`clang-format` wraps C at 80 columns but deliberately leaves the ACSL annotations alone, and nine of
them are longer than that.

`.clang-tidy` selects `bugprone`, `cert`, `clang-analyzer`, `misc`, `performance` and `readability`,
and its suppressions are each a deliberate project convention, so a new finding is a real one:

- `misc-redundant-expression` fires on `x == x` in `src/fp.h`, which is the libm-free NaN test;
- `readability-uppercase-literal-suffix` and `readability-trailing-comma` contradict the existing
  `0u` and enum style;
- `readability-math-missing-parentheses` and `clang-analyzer-security.insecureAPI.*` fire only in
  test code (`fprintf_s` is not POSIX);
- `python/ext/.clang-tidy` drops `readability-identifier-naming`, because the extension follows
  CPython's `BisectionObject`/`BisectionType` naming rather than the library's `lower_case`;
- `test/c/.clang-tidy` and `test/install/.clang-tidy` drop `cert-err33-c` (the harness reports
  through `fprintf` and exits) and `clang-analyzer-optin.core.EnumCastOutOfRange`
  (`test_status.c` casts an out-of-range value on purpose).

`script/dev.sh test` runs it over every C source with `--warnings-as-errors='*'`, using the
`compile_commands.json` that `CMAKE_EXPORT_COMPILE_COMMANDS` writes into the build directory. It
takes `DIANA_CLANG_TIDY` when set, else the first `clang-tidy` on `PATH`, else the Homebrew LLVM one; when
none is found the step prints that it is skipped instead of failing, because `clang-tidy` is not a
pinned dependency (unlike `clang-format`).

The database has to cover `python/ext/`, so `script/dev.sh config` runs `uv sync` before `cmake` and
passes `-DPython_EXECUTABLE=.venv/bin/python`, which makes the entries describe the same interpreter
the pytest suite runs against. The step fails outright when the entry is absent: clang-tidy then
falls back to a guessed compile command, loses `<Python.h>`, and turns the failed parse into findings
across every file that are artefacts rather than defects.

## Python binding

- `python/ext/` holds the C sources of the extension module `diana._diana`: `module.c` (module
  definition, `PyInit__diana`), `module.h` (declarations shared across files), `status.c` (status
  constants, `status_str`, `BracketError`, and `diana_py_raise`, which maps a `diana_status` to a
  Python exception), `convert.c` (argument converters for `PyArg_Parse*` `O&`), and one file per
  kernel (`bisection.c`, the `Bisection` type). A new kernel adds `python/ext/<kernel>.c` with a
  `diana_py_<kernel>_exec(PyObject *m)` that registers its types and functions, declares it in
  `module.h`, calls it from `PyInit__diana`, and lists the file in `CMakeLists.txt`.
- `python/src/diana/` is the pure-Python package: `_error.py` (all exceptions), one private driver
  module per kernel (`_bisection.py`: `diana.bisection`), and `__init__.py`, which only re-exports.
  Driver modules are private so that a module name never shadows the function of the same name.
- The extension sources live outside the package directory so the wheel does not ship them.
- `Bisection.__new__` allocates an uninitialized state with status `ERR_ARG`. `step` and `result`
  reject it until `__init__` succeeds; a rejected reinitialization preserves a prior valid state.

## Local workflow (`script/dev.sh`)

`script/dev.sh <command>` runs the local steps from the repository root:

- `config [cmake option...]`: configures `DIANA_BUILD_DIR` (default `build`, separate from
  scikit-build's `build/<wheel tag>`) with tests on, `DIANA_BUILD_TYPE` (default `Debug`), and
  `DIANA_SANITIZER` (default `ON`), using Ninja when available; then `uv sync` with the `test`,
  `lint`, and `spec` groups.
- `build`: `cmake --build`, then `uv sync --reinstall-package diana`, because uv does not rebuild
  the extension when only C sources change.
- `test`: ctest (including `install`/`find_package`), pytest, ruff, and the `clang-format` check
  of `style_c`.
- `verify`: the steps of [Local verification](#local-verification), with the Clight step as a
  check. Rocq, CompCert, and Frama-C run through `opam exec` in `DIANA_OPAM_SWITCH` (default: the
  current switch), so a Homebrew `rocq` on `PATH` is not picked up.

## Test

`test/c/` holds the ctest suite: one executable per kernel, each registered with ctest.
`test/c/check.h` is a dependency-free assertion helper that exits non-zero on failure.
`test/python/` holds the pytest suite. With `DIANA_BUILD_TEST=ON` (outside scikit-build), ctest also
installs the build into `<build>/install-test` (test `install`) and builds and runs the consumer
project `test/install/` against it with `find_package(diana)` (test `find_package`); the consumer is
linked with the parent's `CMAKE_EXE_LINKER_FLAGS` for coverage builds; sanitizer runtime options
come from the installed target. On macOS, the consumer inherits the configured architecture
list, SDK, and deployment target, including universal builds.

The pytest suite also checks the spec gate with temporary spec and expectation files and mocked
prover execution. The `test` dependency group includes PyYAML for those checks.

`uv run script/check_wheel.py` builds static and shared wheels in separate temporary directories,
checks their runtime-library contents and absence of development artifacts, removes their build
trees, and installs each into a fresh uv virtual environment. An isolated Python process outside
the checkout imports Diana and checks bisection of `x*x - 2`, with loader-path overrides removed.
This tests the installed wheel without relying on the development environment or build RPATHs.

Expected values in `test/c/test_bisection.c`:

- The state-machine test checks the bracket invariant after every step. The width halves each step,
  so `(b - a) / 2^n <= tol` holds at `n = ceil(log2((b - a) / tol))`: 41 steps for `[0, 2]` and
  `tol = 1e-12`.
- With `tol = 0` the final bracket is a pair of adjacent doubles, so the estimate is within 1 ulp of
  the root, and the iteration stops when the endpoints are adjacent.
- `c = 0.5` is the midpoint of `[0, 1]`, so the first step hits the root exactly; a root at an
  endpoint makes `init` report convergence without any step.
- The large-magnitude case uses a bracket at the admissible limit `DBL_MAX/2`; the midpoint must stay
  inside the bracket.
- The callback wrapper evaluates `f(a)`, `f(b)`, then once per step, so `n == iter + 2`; for `[0, 2]`
  and `tol = 1e-6`, `iter = ceil(log2(2 / 1e-6)) = 21`.
- Worst case of `tol = 0`: from a width of `DBL_MAX < 2^1024` down to adjacent subnormals `2^-1074`
  apart takes `1024 + 1074 = 2098` halvings, which the root `DBL_TRUE_MIN` in
  `[-DBL_MAX/2, DBL_MAX/2]` attains. The Python default `max_iter = 2100` is chosen to cover it.
  BISECTION-B4 proves termination and the loose bound `n <= lattice`, not this constant;
  `spec/bisection.md` ("What B4 does not say") records why the tight bound is still only measured,
  so this test is what pins it.
- A rejected `init` or `step` leaves the state unchanged (`test_error_keeps_state`); the Python
  binding relies on it when `Bisection.__init__` is called again with bad arguments or `step` gets a
  non-finite value.

Expected values in `test/c/test_trapezoidal.c` and `test/python/test_trapezoidal.py`:

- The rule is exact for affine `f`. The affine cases use samples and `h` with few significant bits
  (integers or quarter-integers, `h` in `{1/2, 3/4, 2^-7}`), so every partial sum and the final
  product are representable and the binary64 result equals the integral: 20 for `2x + 1` on
  `[0, 4]`, 16.5 for `7 - x` on `[0, 3]`, and `1000 * 500 / 128 = 3906.25` for `3i - 1000`,
  `i = 0..1000`, whose samples change sign.
- `y = {2^53, 1, 1, 2^53}` pins the summation order: after the halved endpoints, `2^53 + 1` is a tie
  that rounds to even, `2^53`, at each interior step, so the result is `2^53` rather than the exact
  `2^53 + 2` that summing the interior first would give.
- Overflow cases have finite samples and `h` and overflow in exactly one operation: the endpoint
  sum (`{DBL_MAX, DBL_MAX}`, whose exact rule `DBL_MAX` is representable), an interior addition, or
  the product with `h`. `h = 0` does not mask an overflow in the sum, since `0 * inf` is NaN.
- `0.5 * DBL_TRUE_MIN` is a tie between 0 and the smallest subnormal and rounds to `+0`: underflow
  is a finite result, not an error.
- The Python Hypothesis test requires bitwise agreement (value and sign of zero) with the same
  sequential evaluation in Python floats, which are binary64 with separate rounded operations, and
  `ValueError` exactly when that evaluation is not finite.
- The rounding test checks the TRAPEZOIDAL-B2 bound against the rule evaluated exactly in
  `fractions.Fraction`, on scaled random samples in the normal range, on `{DBL_TRUE_MIN, 0}` with
  `h = 1` (the halving underflows: the result is 0 and the error is `eta = 2^-1075`), and on
  samples near `2^-1000` with `h = 0.1 * 2^-60` (the product underflows). In both underflow cases
  the error exceeds the `gamma_n |h| A` term alone, so the `eta` terms are needed.
- The convergence test integrates `exp` on `[0, 1]` against `e - 1` from mpmath at 40 digits, for
  `m = 16, ..., 256` panels. TRAPEZOIDAL-A2 with `M2 = e` bounds the error by `e h^2 / 12`, and
  convexity makes it positive. By Euler-Maclaurin the error is
  `(e - 1) h^2 / 12 - (e - 1) h^4 / 720 + O(h^6)`, so each halving of `h` divides it by
  `4 (1 - h^2 / 80) + O(h^4)`, within `2e-4` of 4 for `h <= 1/16`; the test allows `1e-3`. Rounding
  and the error of `math.exp` (about `1e-13` in all) are negligible against the smallest error,
  about `2e-6`.

Expected values in `test/c/test_simpson.c`:

- The rule is exact for cubic `f`. The cubic cases use samples and `h` with few significant bits,
  so every partial sum and the product with `h` are representable and only the division by 3 can
  round: 64 for `x^3` on `[0, 4]`; `28/3`, rounded once, for `x^3 - 2x^2 + x + 1` on `[-1, 3]` with
  `h = 1/2` (the weighted sum is exactly 56); and 26000007000 for `(i - 400)^3 + 7`,
  `i = 0..1000`, whose samples change sign (3250000875 with `h = 2^-3`).
- Three cases pin the operation order. `{2^53, 1/2, 1/4, 1/2, -2^53}` gives 4.5 because the
  endpoint pair cancels before the weighted interior is added; adding the interior to `2^53` first
  would round to 4. In `{0, 2^53, 0, 1, 0, -2^53, 0}` the odd sum is `2^53 + 1 = 2^53` (a tie,
  rounded to even) and then 0, so the result is 0; summing right to left would give 4. The even sum
  is pinned the same way.
- Overflow cases have finite samples and `h` and overflow in exactly one operation: the endpoint
  sum, either interior sum, either scaling by 4 or 2, either of the two additions forming `s`, or
  the product `h * s`. Two of them have a representable exact result (`h * 4 * DBL_MAX / 3` with
  `h = 1/4`, and `DBL_MAX / 2` from `h = DBL_MAX / 4` and `s = 6`): the kernel's range is limited
  by its intermediates, as `spec/simpson.md` states.
- `DBL_TRUE_MIN / 3` rounds to `+0`: underflow is a finite result, not an error.

Expected values in `test/c/test_euler.c`:

- Exact steps use values with few significant bits, so the product and the sum are exact; the
  100-component case checks `y_out[i] = i/2 - 48.5`.
- `y = -1`, `h = 1 + 2^-52`, `f = 1 - 2^-52` pins the separately rounded product:
  `h * f = 1 - 2^-104` rounds to 1 and the result is `+0`, where a fused multiply-add would give
  `-2^-104`.
- `h = 0` keeps each `y[i]`, including its sign of zero (`+0 + -0 = +0`, `-0 + -0 = -0`).
- `0.5 * DBL_TRUE_MIN` is a tie that rounds to `+0`: underflow is not an error. `DBL_MAX + 1`
  rounds back to `DBL_MAX`, a finite result.
- Overflow cases have finite inputs and overflow in exactly one operation, the product or the sum.
- Two failing cases, one in the last component and one in the first, check that `y_out` keeps its
  sentinel values: the first pass rejects before the second pass writes.
- The wrapper cases keep every iterate exact: `y' = -y` with `h = 1/2` halves the state each step,
  the rotation `y' = (y2, -y1)` with `h = 1` stays on integers (`(1, 0)` to `(-2, -2)` in three
  steps), and `y' = t` from `t0 = 1` with `h = 1/4` records the times `1, 1.25, 1.5, 1.75` and ends
  at `(1 + 1.25 + 1.5 + 1.75) / 4 = 1.375`. A derivative that turns infinite on the third call
  stops after two steps with `y` at the second state, and `y' = -y` with `h = -2` from `DBL_MAX/2`
  overflows on the first step and leaves `y` unchanged.

Expected values in `test/python/test_euler.py`, beyond the cases it shares with the C test:

- The Hypothesis test draws `y` and `f` of equal length (1 to 20) and requires bitwise agreement
  with `y[i] + h*f[i]` in Python floats, which round the product and the sum separately, and
  `ValueError` exactly when a component is not finite.
- The rounding test checks EULER-B2 on 500 random components in the normal range and 500 with
  subnormal inputs, against exact `fractions.Fraction` arithmetic.
- The convergence test integrates the rotation `y' = (y2, -y1)` from `(0, 1)` to `t = 1`, where
  the solution is `(sin t, cos t)`. In the max norm `F` is 1-Lipschitz and `|y''| <= 1`, so
  EULER-A2 bounds the error by `(h/2)(e - 1)`; the measured error is about 0.49 of that. Halving
  `h` divides the error by 2 up to an O(h) correction, measured at most 0.016 for `h <= 1/16`
  (ratios 1.985 to 1.999); rounding, about `n u`, is far below the smallest error
  of about 1.6e-3. The test allows 0.05.
- The extension's own `out` checks are tested directly on `diana._diana.euler_step`: a read-only
  `out` (`BufferError`), a length mismatch, and `out` equal to or overlapping `y` or `f`.

Expected values in `test/python/test_simpson.py`, beyond the cases it shares with the C test:

- The Hypothesis test draws odd-length lists (3 to 41 samples) and requires bitwise agreement
  (value and sign of zero) with the same two left-to-right sums from `+0`, the regrouping
  `((y0 + yl) + 4 so) + 2 se` and `(h s) / 3` in Python floats, and `ValueError` exactly when that
  evaluation is not finite.
- The rounding test checks the SIMPSON-B2 bound against the rule evaluated exactly in
  `fractions.Fraction`, on scaled random samples in the normal range (1001 samples, `h = 0.1`), on
  samples near `2^-1000` with `h = 0.1 * 2^-60` (the product with `h` underflows), and on
  `{DBL_TRUE_MIN, 0, 0}` with `h = 1` (the division by 3 underflows to 0).
- The convergence test integrates `exp` on `[0, 1]` against `e - 1` from mpmath at 40 digits, for
  `m = 8, ..., 128` panels. SIMPSON-A2 with `M4 = e` bounds the error by `e h^4 / 180`, and
  `exp'''' > 0` makes it positive. By Euler-Maclaurin the error is
  `(e - 1) h^4 / 180 - (e - 1) h^6 / 1512 + O(h^8)`, so each halving of `h` divides it by
  `16 (1 - (3/4)(180/1512) h^2) + O(h^4)`, about `0.022` below 16 at `h = 1/8` (measured
  `15.978`); SIMPSON-B2 bounds the rounding by about `1.3e-14` against the smallest error, about
  `3.6e-11`, so it moves a ratio by at most about `0.006`. The test allows `0.05`.

## CI (`.gitlab-ci.yml`)

Six stages: style (format, naming, spec structure), build (per compiler and configuration), test
(ctest and pytest against the build artifacts), report (code coverage), verify (Frama-C, Lean,
Rocq), and release (the tag release once everything is green). Jobs run as a DAG through `needs:`,
and every job is interruptible so superseded pipelines stop.

Jobs normally run only when a file they depend on changes (`rules: changes:` against the hidden
`.change_*` path lists at the top of the file); a change to `.gitlab-ci.yml` runs everything.
Both coverage jobs also run on every default-branch pipeline, including changes only to `doc/`
or top-level Markdown files, so the README badges have values in the latest successful pipeline.
Merge-request pipelines retain the path filters. Tag and scheduled pipelines (`.rule_full`)
always run every job, so a release is gated on a full run. Because a job can be absent from a
pipeline, `needs:` on a job from another path set is `optional: true`. When adding a job or a file
a job reads, extend the matching list.

- `style_c` checks the C sources (`include/`, `src/`, `test/c/`, `test/install/`, `python/ext/`) with the pinned
  `clang-format --dry-run --Werror`. It installs only the `lint` group (`uv sync --only-group`), so
  it builds nothing and skips the compiler install of `.uv`.
- `test_install` runs the C suite and the installed consumer twice: once with
  `CMAKE_INSTALL_INCLUDEDIR=include/custom`, once with `BUILD_SHARED_LIBS=ON`, so the exported
  include path and the versioned shared install are both covered. The release job requires it.
- `test_python` runs the Python suite and package metadata checks, then `script/check_wheel.py`
  to check both static and shared installed wheels.
- `style_git` runs `script/check_commit.sh` on the commits since the previous pipeline of the
  branch, `CI_COMMIT_BEFORE_SHA..CI_COMMIT_SHA`. GitLab sets `CI_COMMIT_BEFORE_SHA` to zeros in
  merge request, scheduled, manual and tag pipelines and on a branch's first push, so a merge
  request pipeline checks the merge request's commits (`CI_MERGE_REQUEST_DIFF_BASE_SHA..`, up to
  `CI_MERGE_REQUEST_SOURCE_BRANCH_SHA` in a merged-results pipeline, whose own head is a merge
  commit), and the others check the whole history, as does a force push whose previous head is no
  longer in the clone. It has no path filter, because a commit needs checking whatever it touches,
  and `GIT_DEPTH: "0"`, so that every base commit is present.
- `style_name` enforces single-form noun directory names by rejecting plural directories. It runs
  on any selected path and scans the whole tree, so a plural directory added in a doc-only push is
  caught by the next pipeline that runs it.
- `coverage_c` rebuilds the C library and ctest suite with `--coverage` (Debug, no sanitizer) and
  reports `src/` and `include/` with gcovr; the job's coverage value is the line rate.
- `coverage_python` rebuilds the extension with `--coverage` (`SKBUILD_CMAKE_DEFINE`), runs pytest
  under pytest-cov for the Python package, and reports the extension source `python/ext/` with
  gcovr. The job's coverage value is the Python line rate; both Cobertura files feed the merge
  request diff annotation.

- `style_python` runs the structural spec gate (`--no-report`). It does not regenerate the report:
  without `--run` every prover status would read `planned`, and no CI job runs both Lean and Rocq,
  so the report is regenerated locally with `--run` and committed (see
  [Local verification](#local-verification)).
- `verify_lean` runs `script/check_spec.py --run --strict --prover lean --no-report` with the
  image's system `python3` (3.11 on Debian bookworm), not with `uv`, so ruff checks `script/`
  against Python 3.11 (`per-file-target-version` in `pyproject.toml`). The script exits non-zero
  when the Lean check fails to run, a listed Lean theorem is missing, or a theorem depends on an
  axiom outside `script/axiom_allow.yaml`. Selecting `--prover lean` excludes Rocq-only layers
  and Frama-C coverage from this gate.
- `verify_frama_c`: 162/162 goals are proved locally with Frama-C 33.0 and Alt-Ergo 2.6.4; the CI
  image is 32.1 until a 33 tag exists. If 32.1 behaves differently, pin the image forward rather
  than re-adding `allow_failure`.
- `verify_lean` uses `LEAN_IMAGE`, a stock Debian image until the project image
  (`ci/docker/lean.Dockerfile`) is in the registry.
- `verify_rocq` compiles layer A on the stock MathComp image (`mathcomp/mathcomp:2.6.0-rocq-prover-9.2`,
  Rocq 9.2 with MathComp 2.6.0) after `opam install coq-coquelicot.$COQUELICOT_VERSION`, so layer A
  may use Coquelicot integrals and derivatives. The image already carries Coquelicot's only
  dependency, MathComp ssreflect, so the job compiles Coquelicot alone; on the stock
  `rocq/rocq-prover` image the same install would also build elpi, Hierarchy Builder and MathComp.
  The image predates Coquelicot 3.4.5, hence the `opam update` of `rocq-released` first. It does not
  run the Rocq axiom gate: `make check` imports every layer.
- No CI job installs Flocq, CompCert, or VST, so every CI image is public and stock. Layers B and
  C-VST, the Rocq axiom gate, and the Clight AST are checked only locally.
- `release` is the last job of a tag pipeline, gated on every test and verification job.

## Container image (`ci/docker/`)

- `lean.Dockerfile`: the pinned Lean toolchain with the Mathlib cache pre-fetched, so CI jobs do not
  download several GB per run. Rebuild when `verification/lean/lean-toolchain` or
  `lake-manifest.json` changes.

## Local verification

CI checks the C code (build, ctest, pytest, Frama-C WP), layer A in Lean with its axiom gate, and
that layer A compiles in Rocq. Everything that needs Flocq, CompCert, or VST runs only in the opam
switch of `CONTRIBUTING.md`, and a green pipeline says nothing about it. After a change to `src/`,
`include/`, `verification/`, or `spec/` (`script/dev.sh verify` runs all four):

1. If a verified kernel or a header it includes changed, regenerate its Clight AST with the
   `clightgen` command in `CLAUDE.md`. Nothing in CI notices a stale AST. `script/dev.sh verify`
   reads the CompCert target from `compcert.config` in the opam switch, regenerates every
   `verification/clight/<kernel>_<target>.v` of that target from `src/<kernel>.c` into a temporary
   file, and fails if it differs from the committed one; with `DIANA_CLIGHT_UPDATE=1` it
   overwrites the committed file and goes on, so the Rocq build then checks the proofs against the
   new AST. On a target with no committed AST it skips the check.
2. `cd verification/rocq && make && make check` builds layers A, B, and C-VST and prints their
   axioms. `make check` needs the generated `CheckSpec.v`, which step 4 writes; on a fresh clone
   run step 4 first, or just use `script/dev.sh verify`, which orders them.
3. `script/verify_frama_c.sh` runs `script/run_frama_c.sh` and `script/check_frama_c.sh` for
   each `<source> <goal-count>` row of `verification/frama-c/expectation.txt`, with reports in
   one consolidated `verification/frama-c/report.txt`, one `==> <source> <==` section per row
   (CI runs the same script with Frama-C 32.1 and uploads that single file).
4. `uv run script/check_spec.py --run --strict` runs both provers' axiom gates and rewrites the
   report at the end of `doc/verification.md`; commit the report. `--strict` is what
   `script/dev.sh verify` passes, so `verify` fails on a theorem that is listed in `spec/` but not
   proved (`missing`), not only on a disallowed axiom. The full strict gate also requires exactly
   one valid positive Frama-C expectation count for the `acsl` file of each ACSL theorem, so the WP
   loop cannot silently omit it. The fresh WP run and report check remain step 3; an expectation
   count alone is not proof evidence. As of v0.2.0 every theorem listed in `spec/` is proved, so it
   exits 0. Note that this is a gate on the listed theorems, not a claim beyond them: the callback
   wrappers in `src/wrapper/` have no proof, and the VST funspecs leave the NULL and other
   argument-error paths to Frama-C.

`clightgen` output depends on the target CompCert was configured for (the `Info` module records
the architecture and ABI, and the builtin list differs between AArch64 and x86-64), so each AST is
named after its target, `<arch>[_<model>]_<system>` from `compcert.config`
(`bisection_aarch64_macos.v`; an x86-64 Linux one would be `bisection_x86_64_linux.v`), and the VST
proofs import that module by name. Regenerate an AST only on its own target, and commit it only
together with the source change that caused it and a passing `make`. On another target the Rocq
build is expected to compile the proofs against the committed AST (not yet checked on a non-macOS
target), but cannot regenerate it. A second target needs its own CompCert switch and a second
committed AST.

## Rocq build (`verification/rocq/Makefile`)

Requires the opam switch described in `CONTRIBUTING.md`. `make` builds everything and `make check`
prints the axioms of the listed theorems; `check` compiles the generated `CheckSpec.v`, so run
`uv run script/check_spec.py --run --prover rocq` (or `script/dev.sh verify`) at least once first,
because that file is generated and not committed. `make real` builds layer A only (Stdlib and Coquelicot),
which is what the `verify_rocq` image can build; it calls `rocq compile` directly because the
generated makefile scans the dependencies of every file in `_CoqProject` and warns that Flocq,
CompCert, and VST are missing.
