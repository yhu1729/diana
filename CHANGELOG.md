# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

#### C library

- Classical fourth-order Runge–Kutta step in reverse communication, `diana_rk4_stage` and
  `diana_rk4_step` in `diana/rk4.h`. The caller evaluates the four slopes; `diana_rk4_stage(y, k,
  d, h, stage, y_out)` writes the point of stage 2, 3 or 4 (`y + (h/2) k` for stages 2 and 3,
  `y + h k` for stage 4, the coefficient computed once), and `diana_rk4_step(y, k1, k2, k3, k4, d,
  h, y_out)` writes `y + h ((k1 + k4) + 2 (k2 + k3)) / 6` in that operation order. Both check
  every component before writing any, so `y_out` is untouched on `DIANA_ERR_ARG` (a NULL pointer,
  `d == 0`, a stage outside 2 to 4, a non-finite input or an overflow in any operation). Frama-C
  WP proves the ACSL contracts (98 goals, RK4-C1, `spec/rk4.md`). `test/c/test_rk4.c` covers both
  functions at 100% line and branch coverage, and the compiler-comparison corpus has 544 RK4
  cases; every gcc and clang build matches CompCert bitwise.
- Callback wrapper `diana_rk4(fn, ctx, t0, h, nstep, y, d, work, done)` in `diana/wrapper.h`, with
  the `diana_ode_fn` of `diana_euler` and a `work` of `5 d` doubles. Step `k` evaluates `fn` at
  `t0 + k h`, `t0 + (k + 0.5) h` (twice) and `t0 + (k + 1) h`, each computed from `k`. A failing
  stage or step returns `DIANA_ERR_ARG` with `y` at the last good state. Unverified, like
  `diana_euler`.
- `diana_euler_step_unchecked(y, f, d, h, y_out)` in `diana/euler.h`, an opt-in explicit Euler
  step without the finiteness check, in its own source file `src/euler_step_unchecked.c`: it
  rejects NULL pointers and `d == 0` like `diana_euler_step`, then writes every component in one
  pass in the same operation order, NaN and ±∞ included, and returns `DIANA_OK`. Where the
  checked step succeeds the two write the same bits; `diana_euler_step` and the `diana_euler`
  wrapper are unchanged. Its theorems are in `spec/euler_unchecked.md`: Frama-C WP proves its
  ACSL contract (EULER-UNCHECKED-C1, 19 goals) and VST that it writes the binary64 model
  unconditionally (EULER-UNCHECKED-C2). `test/c/test_euler.c` covers it at 100% line and branch
  coverage, and the compiler corpus runs both steps on every Euler case, every gcc and clang
  build matching CompCert bitwise, NaN results included. On an Apple Silicon Mac the unchecked
  kernel is 2.4 to 4.9 times faster (about 0.1 to 0.3 ns per component against 0.44 to 0.67).
- `diana_rk4_stage_unchecked(y, k, d, h, stage, y_out)` and
  `diana_rk4_step_unchecked(y, k1, k2, k3, k4, d, h, y_out)` in `diana/rk4.h`, the opt-in RK4
  stage and step without the finiteness check, each in its own source file
  (`src/rk4_stage_unchecked.c`, `src/rk4_step_unchecked.c`): they reject the argument errors of
  the checked functions (a NULL pointer, `d == 0`, a stage outside 2 to 4), then write every
  component in one pass in the same operation order, NaN and ±∞ included, and return
  `DIANA_OK`. Where the checked function succeeds the two write the same bits; the checked
  functions and the `diana_rk4` wrapper are unchanged. Their theorems are in
  `spec/rk4_unchecked.md`: Frama-C WP proves the ACSL contracts (RK4-UNCHECKED-C1 and C2, 21 and
  22 goals) and VST that each writes the binary64 model unconditionally (RK4-UNCHECKED-C3 and
  C4). `test/c/test_rk4.c` covers both at 100% line and branch coverage, and the compiler corpus
  runs the checked and unchecked functions on every RK4 case (544 more cases). On an Apple Silicon
  Mac the unchecked stage is 2.8 to 4.8 times faster (about 0.10 to 0.16 ns per component against
  0.44 to 0.52) and the unchecked step 2.2 to 4.5 times (0.25 to 0.41 ns against 0.86 to 1.23).

#### Python binding

- `diana.rk4_stage(y, k, h, stage)` and `diana.rk4_step(y, k1, k2, k3, k4, h)` return a new
  `array.array("d")` from the kernels, reading float64 buffers in place and copying other
  iterables (module `diana._rk4`; extension functions `diana._diana.rk4_stage` and `rk4_step`
  with an explicit `out` that must not overlap an input). `diana.rk4(f, t0, y0, h, nstep)` loops
  in Python with a callable `f(t, y)`, at the same times as `diana_rk4`, copying each slope so
  `f` may reuse its output buffer. A stage other than 2, 3 or 4, a length mismatch and a
  non-finite component raise `ValueError`. `test/python/test_rk4.py` covers the binding (the
  driver and `python/ext/rk4.c` at 100% line and branch coverage), including bitwise agreement
  with Python float arithmetic, RK4-B3 and RK4-B5 against exact rationals, and fourth-order
  convergence on the rotation.

#### Verification

- Lean and Rocq prove RK4 layer A (`spec/rk4.md`, RK4-A1 to A7): the step-size derivatives of the
  increment through third order as explicit jets (A1), the order conditions
  `Phi(0) = G`, `Phi'(0) = E2/2`, `Phi''(0) = E3/3`, `Phi'''(0) = E4/4` without symmetry of the
  second derivative (A2), the local truncation bound `(M5/120 + N4/24) h^5` (A3), the Lipschitz
  constant `L (1 + hL/2 + (hL)^2/6 + (hL)^3/24)` of the increment (A4), convergence
  `tau/(hL) (e^(Lkh) - 1)` from a per-step local truncation `tau` (A5), autonomization through
  `G(t, y) = (1, F(t, y))` (A6), and the order-4 global bound
  `((M5/120 + N4/24) h^4 / L) (e^(Lkh) - 1)` (A7). Lean takes Fréchet derivatives up to third
  order; Rocq takes the chain rule along curves and multilinearity, shown satisfiable for linear
  fields by `linear_instance`. The new shared modules `Diana.Real.Taylor` (Lean, Rocq) bound a
  Taylor remainder through a Lipschitz top derivative, and `one_step_pow` is factored out of
  `one_step_error` in `Diana.Real.OneStep`.
- Flocq proves RK4 layer B (`verification/rocq/theory/Float/RK4.v`): a finite stage or step
  component certifies every operation of its evaluation (RK4-B1, RK4-B4); the stage coefficient
  `fl(h/2)` is within `eta` of `h/2` and exact for `|h| >= 2^-1021` (RK4-B2); a stage component is
  within the EULER-B2 bound of the exact `y + c k`, plus `(1 + u)^2 |fl(h/2) - h/2| |k|` (RK4-B3);
  and a step component is within `u |T| + (1 + u)(gamma_4 |h| A / 6 + (1 + u) eta / 6 + eta)` of
  the exact `T = y + h (k1 + 2 k2 + 2 k3 + k4) / 6`, `A = |k1 + k4| + 2 |k2 + k3|` (RK4-B5).
- VST proves `diana_rk4_stage` and `diana_rk4_step` against the committed AArch64 macOS Clight
  AST `verification/clight/rk4_aarch64_macos.v` (RK4-C2, RK4-C3): each returns `DIANA_OK` and
  writes the C-order model exactly when every component is finite, and leaves `y_out` unchanged
  otherwise; the C-order models are the Flocq models (RK4-C4, RK4-C5).
- Flocq proves that a component written by an unchecked kernel is finite exactly when its inputs
  are finite and none of its operations overflows, each correctly rounded exact result staying
  below `2^1024` in magnitude (EULER-UNCHECKED-B1, RK4-UNCHECKED-B1 and B2, in
  `verification/rocq/theory/Float/EulerUnchecked.v` and `RK4Unchecked.v`, on the new
  `fadd_finite_iff`, `fmul_finite_iff` and `fdiv_finite_iff` of `Diana.Float.Sum`): a finiteness
  check of the output after the call rejects exactly what the checked kernel rejects. Each
  unchecked function has its own Frama-C expectation row, Clight AST
  (`<source>_aarch64_macos.v`) and VST file (`verification/rocq/theory/VST/EulerStepUnchecked.v`,
  `RK4StageUnchecked.v`, `RK4StepUnchecked.v`); `src/euler.c` and its proofs are back to the
  checked step alone (49 WP goals).
- The spec gate accepts a method name with `_`, written `-` in its theorem IDs
  (`EULER-UNCHECKED-C1` in `spec/euler_unchecked.md`), and a list of source files as `kernel`.

## [0.3.0] - 2026-10-16

### Added

#### C library

- Newton's method in reverse-communication form, `diana_newton_init`, `diana_newton_step` and
  `diana_newton_result` over a caller-owned `diana_newton_state` (`x`, `dx`, `tol`, `iter`,
  `max_iter`) in `diana/newton.h`. `step` consumes `f(x)` and `f'(x)`: an exact zero `f(x)`
  converges at once whatever `f'(x)`; a zero `f'(x)` (either sign of zero) against a non-zero
  `f(x)` is the new status `DIANA_ERR_SINGULAR` with the state unchanged; otherwise the
  correction `fl(f/f')` and the iterate `fl(x - dx)` are each checked, and a non-finite one (a
  subnormal `f'` against a large `f`, an overflow) is `DIANA_ERR_ARG` with the state unchanged,
  like a NaN or infinite input; a finite step stores `dx` and the new `x`, increments `iter`, and
  returns `DIANA_OK` when `|dx| <= tol` or the iterate did not change, `DIANA_ERR_MAXITER` at the
  step limit, else `DIANA_CONTINUE`. `init` takes `x0`, `tol >= 0` and `max_iter > 0` and always
  returns `DIANA_CONTINUE`. Frama-C WP proves the ACSL contracts (103 goals, NEWTON-C1): the
  state invariant, `iter` increments, the meaning of each status, and the state unchanged on
  `DIANA_ERR_ARG` and `DIANA_ERR_SINGULAR`. `test/c/test_newton.c` covers every path of the
  kernel and the wrapper at 100% line and branch coverage.
- `DIANA_ERR_SINGULAR` (-4, "zero derivative or pivot") in `diana/status.h`: the step of a
  method is undefined because a derivative (Newton) or, in the planned linear-algebra kernels, a
  pivot is zero. The call writes nothing.
- Callback wrapper `diana_newton(f, ctx, x0, tol, max_iter, root, iter)` in `diana/wrapper.h`,
  with `diana_newton_fn f(x, &dfx, ctx)` returning `f(x)` and writing `f'(x)`; `*dfx` is reset to
  0 before each call so a callback that never writes it fails cleanly. Unverified, like
  `diana_bisection`.

#### Python binding

- `diana.Newton(x0, tol, max_iter=100)` (reverse-communication state with `step(fx, dfx)`,
  `result() -> (root, dx)` and read-only fields) and the driver `diana.newton(f, x0, tol,
  max_iter=100)` for a callable returning `(f(x), f'(x))` (module `diana._newton`). `tol` is
  required because Newton's method has no parameter-free stopping rule: with `tol = 0` the
  iteration near a simple root commonly ends in a two-cycle of adjacent doubles until
  `max_iter`. A zero `f'(x)` raises the new `diana.SingularError` (a `ValueError`, from
  `DIANA_ERR_SINGULAR`; also `diana.ERR_SINGULAR`); a non-finite `f(x)` or `f'(x)` and an
  overflowing correction or iterate raise `ValueError` with a message naming which;
  `MaxIterError` carries the iterate as `estimate` and `|dx|` as `width`.
  `test/python/test_newton.py` covers the binding.

#### Verification

- Newton's method is proved through every layer (`spec/newton.md`, 10 theorems). Lean and Rocq
  prove NEWTON-A1 (`Diana.Real.Newton.step_error`: `|x - f(x)/f'(x) - r| <= (M/(2m))(x - r)^2`
  for `|f''| <= M` and `|f'| >= m` on an interval containing `x` and the root `r`, `f''` not
  necessarily continuous) and NEWTON-A2 (`converge`: from `|x0 - r| <= delta` with
  `q = M delta/(2m) < 1`, every iterate stays within `delta` and `|x_n - r| <= delta q^(2^n - 1)`),
  by the mean-value bound of `Diana.Real.Quadrature` applied along the segment from `x` to `r`.
  Flocq proves NEWTON-B1 (`finite_result`), NEWTON-B2 (`forward_error`: the step error
  `u |x - f/f'| + (1 + u)(u |f/f'| + eta)` per EULER-B2 with a quotient) and NEWTON-B3
  (`stagnation`: `fl(x - dx) = x` implies `|dx| <= ulp(x)/2`, the meaning of the "iterate
  unchanged" stop). VST proves `diana_newton_result`, `diana_newton_init` and
  `diana_newton_step` against the committed AArch64 macOS Clight AST
  `verification/clight/newton_aarch64_macos.v` (NEWTON-C2 to C4, C-order models `c_init`/`c_step`
  with every exit, an error leaving `*s` unchanged) and that `c_step` writes the Flocq `fstep`
  (NEWTON-C5).

- VST proves `diana_bisection_init` (BISECTION-C6, `Diana.VST.Bisection.body_diana_bisection_init`)
  and `diana_bisection_step` (BISECTION-C7, `body_diana_bisection_step`) against the committed
  AArch64 macOS Clight AST `verification/clight/bisection_aarch64_macos.v`, closing the last VST
  gap in the shipped kernels. For a non-NULL state, each returns the status and writes the state of
  a model in the C's evaluation order (`c_init`, `c_step`: every exit, `iter`, `max_iter`, the
  tolerance and stagnation stops), and an error leaves `*s` unchanged. `c_step` writes the Flocq
  `fstep` bracket (BISECTION-C8, `c_step_fstep`), the state `c_init` accepts satisfies the layer-B
  invariant `Bracket` (BISECTION-C9, `c_init_bracket`), and a `DIANA_CONTINUE` step keeps
  `Bracket` and `Next` (BISECTION-C10, `c_step_next`), so BISECTION-B2 to B4 apply to every state
  an `init`/`step` run reaches.

#### Tests and tooling

- Local bitwise differential test between the CompCert build of the kernels, which the VST proofs
  cover, and the gcc/clang builds that ship: `script/compare_compiler.sh` builds `src/*.c` with
  the corpus driver `test/c/test_compiler.c` (1128 cases: every argument error, NaN and ±∞ inputs,
  `h = ±0`, subnormals, overflow in each operation, the 2098-step bisection worst case, the Newton
  two-cycle and double root, seeded random inputs) with `ccomp` and with each available gcc and
  clang at `-O0`, `-O2` and `-O3`, and
  fails on any difference in the printed bit patterns. `script/dev.sh verify` runs it and skips it
  without `ccomp`. On macOS it sets an unset `MACOSX_DEPLOYMENT_TARGET` to the running version, so
  Homebrew GCC 13 can build there. The candidates include the `clang` of every Homebrew LLVM keg
  (`llvm` and `llvm@N`). On AArch64 macOS, Apple clang 21, GCC 13.4, 14.4, 15.3 and 16.2, and
  LLVM clang 20.1, 21.1, 22.1 and 23.1 match CompCert 3.17 bitwise. ctest runs the driver as the `compiler` test, without
  the comparison.
- `test/doc/test_example.py` checks the examples in `doc/api/`: every C program is compiled with
  the strict warning set and `-Werror`, run, and its output compared with the page; every C block
  is checked against the pinned clang-format; the Python sessions run as doctests; and the version
  the CMake consumer requests must match the project's. `test_python` runs it on a change to
  `doc/api/`.
- `ci/docker/lean.Dockerfile` stays root and carries `python3` and `python3-yaml`, and
  `verify_lean` installs apt packages and elan only when `elan` is not on `PATH`, and seeds
  `verification/lean/.lake/packages` from the image's `DIANA_LEAN_CACHE`, so the job runs
  unchanged on the stock Debian image and on the project image.

#### Python

- `python/src/diana/_diana.pyi`, a type stub for the extension module, so the `py.typed` package
  is typed throughout (`Bisection` and `Newton` with their read-only state fields and
  positional-only `step` arguments, the status constants, `BracketError`, `SingularError`,
  `version`, `status_str` and the array functions).

#### Documentation

- Examples in `doc/api/`: a complete CMake consumer project, a C program with its output for every
  kernel and callback wrapper (reverse-communication loop, iteration limit, context pointer, the
  alternating buffers of an Euler loop), and Python sessions in doctest form for every function,
  including NumPy input, the array-argument checks, and the exceptions.
- `doc/roadmap.md`, a list of ideas for future work, one line each.

### Changed

- The CMake option `BUILD_SHARED_LIBS` is renamed `DIANA_BUILD_SHARED_LIB`; the library type is
  set explicitly, so the generic variable of an enclosing project no longer changes it
  (`script/check_wheel.py`, the `test_install` CI job and the docs use the new name).
- `script/check_spec.py` rewrites `doc/verification/report.md` only when both provers ran
  (`--run` without `--prover`), so a structural or one-prover run no longer overwrites the
  committed statuses with `planned`; theorem IDs may contain digits and underscores after the
  first letter (`RK4-A1`); theorems that share a prover constant each receive its result.
- The CMake guard against fast math also inspects the per-configuration flags
  (`CMAKE_C_FLAGS_<CONFIG>`) and rejects `-funsafe-math-optimizations`, and configuration fails
  when `DIANA_VERSION_STRING` in `include/diana/diana.h` differs from the CMake project version.
- `test_python` also runs on a change to `README.md` or `LICENSE`, which it packages and checks.
- `diana.euler` accepts an object with `__index__` for `t0` and `h`, as `diana.euler_step` and
  the other kernels already did through the C `d` converter; a string is still rejected.
- `README.md` is a brief overview: what Diana is, the methods, a quick start, and where the
  documentation is; the technical detail moves to `doc/`.
- The documentation is split by topic and indexed by `doc/README.md`: `doc/api/` (an overview and
  one page per method, each with its C functions, callback wrapper and Python functions),
  `doc/development/` (build, format and lint, Python binding, local workflow, CI), `doc/test/` (the
  test suite and the expected values per method), and `doc/verification/` (trust statement, spec
  gate, Frama-C and Flocq boundary, libm-free helpers, local verification, compiler comparison).
  The generated theorem report moves from the end of `doc/verification.md` to
  `doc/verification/report.md`, which `script/check_spec.py` now rewrites.
- The Lean sources under `verification/lean/` are modules (`module`, `public import`, and a
  `public section`, with `@[expose]` where the file defines something); `Mathlib.Tactic` is a
  private import, used only by proofs.

### Removed

- Windows support: the `WINDOWS_EXPORT_ALL_SYMBOLS` and `RUNTIME` install branches of
  `CMakeLists.txt`, the MSVC flags of `cmake/warning.cmake`, the MSVC libm exception of the ctest
  link, and the `diana.dll`, `Scripts/python.exe` and `PATH` cases of `script/check_wheel.py`.
  Linux and macOS are the supported platforms.

### Fixed

- The API and trust statement specify the runtime floating-point requirements: nearest-even
  rounding, gradual underflow, and disabled traps, maintained by callers and callbacks. Strict
  compiler flags alone do not establish these settings.
- `diana.euler_step` reports `y` and `f` of different lengths as "y and f must have the same
  length"; the message no longer names the `out` buffer, which only the extension function takes
  and which is now checked separately.
- `diana.bisection` rejects a string for `a`, `b`, `tol` and for a value `f` returns
  (`TypeError`), as `diana.Bisection` and `diana.euler` already did, instead of converting it with
  `float`; an object with `__float__` or `__index__` is still accepted. The check is `real` in
  `diana._convert`, shared with `diana.euler`.
- `diana.euler` copies a `bytes` or `bytearray` `y0` element by element, like every other
  iterable, instead of decoding it as raw float64 data (`bytes(16)` gave two zeros, any other
  length a `ValueError` about the item size).
- `spec/bisection.md` no longer claims that a `diana_bisection_step` reporting
  `DIANA_ERR_MAXITER` leaves the state unchanged: BISECTION-C2 guarantees that for
  `DIANA_ERR_ARG` only, and such a step has halved the bracket. BISECTION-B2 states its `Next`
  hypothesis, BISECTION-B4 the bound its listed constant proves, and BISECTION-C4/C5 the funspec
  preconditions (finite input; non-NULL outputs); SIMPSON-B2 states the list-length hypothesis.

## [0.2.0] - 2026-10-15

Milestone M1: the composite trapezoidal and Simpson rules over tabulated samples and the explicit
Euler step, each through every verification layer — error bounds over the reals in Lean and Rocq
(layer A), binary64 bounds in Flocq (layer B), and Frama-C WP plus a VST proof that the C computes
the Flocq model (layer C) — with a Python binding for each and a C callback wrapper for Euler. The
bisection API is renamed after the method, a breaking change (see Changed).

As in 0.1.0, layers B and C-VST, the Rocq axiom gate and the Clight ASTs are checked **locally
only**; CI covers layer A and Frama-C. `doc/verification.md` is the trust statement, and its
generated report lists all 29 theorems as proved.

### Added

#### C library

- Composite trapezoidal rule over tabulated samples, `diana_trapezoidal(y, n, h, result)` in
  `diana/trapezoidal.h`. It returns `DIANA_ERR_ARG` without writing `*result` for NULL
  pointers, `n < 2`, or a non-finite result. Frama-C WP proves its ACSL contract (41 goals,
  TRAPEZOIDAL-C1); `spec/trapezoidal.md` lists the layer-A error bounds, the Flocq
  finiteness and forward-error theorems, and the VST theorem.
- Composite Simpson rule over tabulated samples, `diana_simpson(y, n, h, result)` in
  `diana/simpson.h`, for an odd `n >= 3`: the odd and even interior samples are summed separately,
  left to right from `+0`, and the result is `(h * ((y[0] + y[n-1]) + 4 * so + 2 * se)) / 3`. It
  returns `DIANA_ERR_ARG` without writing `*result` for NULL pointers, `n < 3`, an even `n`, or a
  non-finite result. Frama-C WP proves its ACSL contract (58 goals, SIMPSON-C1); `spec/simpson.md`
  fixes the operation order and lists every Simpson theorem. `test/c/test_simpson.c` covers every
  path of the kernel: argument errors, exact results on cubic data, the operation order, overflow
  in each operation, NaN and infinite samples and `h`, `h = 0`, and underflow to zero.
- Explicit Euler step `diana_euler_step(y, f, d, h, y_out)` in `diana/euler.h`: `y_out[i] =
  y[i] + h * f[i]` with the product rounded before the sum, `y_out` separate from `y` and `f`. It
  returns `DIANA_ERR_ARG` without writing `y_out` for NULL pointers, `d == 0`, or any non-finite
  component; a first pass checks every component before a second pass writes. Frama-C WP proves
  its ACSL contract (49 goals, EULER-C1), and `spec/euler.md` fixes the operation order and lists
  every Euler theorem. `test/c/test_euler.c` covers every path: argument
  errors, exact steps, the absence of contraction, `h = 0`, underflow, overflow in either
  operation, NaN and infinite inputs, and failures that leave `y_out` untouched.
- Callback wrapper `diana_euler(fn, ctx, t0, h, nstep, y, d, work, done)` in `diana/wrapper.h`
  (`diana_ode_fn` callback, `work` of `2 * d` doubles, no allocation): `nstep` Euler steps in
  place, the time of step `k` computed as `t0 + k * h`, and on a failing step `y` left at the last
  good state with `*done` the number of completed steps. Unverified, like `diana_bisection`;
  `test/c/test_euler.c` covers every path at 100% line and branch coverage.

#### Python binding

- Python binding `diana.trapezoidal(y, h)` (driver `diana._trapezoidal`). It reads a
  one-dimensional, C-contiguous, aligned buffer of native float64 in place through the buffer
  protocol, with no NumPy dependency, and copies any other iterable of numbers into an
  `array.array("d")`. It raises `TypeError` for another element type, and `ValueError` for another
  layout, fewer than two samples, or a non-finite result.
- Python binding `diana.simpson(y, h)` (driver `diana._simpson`), with the buffer handling of
  `diana.trapezoidal`: it raises `TypeError` for another element type, and `ValueError` for another
  layout, fewer than three samples, an even number of samples, or a non-finite result.
  `test/python/test_simpson.py` checks the buffer handling, bitwise agreement with a sequential
  binary64 evaluation (Hypothesis), the SIMPSON-B2 rounding bound against exact rational
  arithmetic, and fourth-order convergence against mpmath.
- Python binding `diana.euler_step(y, f, h)` (a new `array.array("d")`) and the driver
  `diana.euler(f, t0, y0, h, nstep)` looping in Python (module `diana._euler`). The extension
  function `diana._diana.euler_step(y, f, h, out)` reads `y` and `f` in place and checks that the
  writable `out` has their length and overlaps neither. `test/python/test_euler.py` checks the
  buffer handling, bitwise agreement with `y + h*f` in Python floats (Hypothesis), the EULER-B2
  bound against exact rational arithmetic, and first-order convergence with the EULER-A2 bound on
  a rotation.

#### Verification

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
- Lean and Rocq prove the Simpson error bounds SIMPSON-A1 (`Diana.Real.Simpson.local_error`, one
  double panel: `M₄·h⁵/90`) and SIMPSON-A2 (`composite_error`, `2p` panels:
  `(b − a)·h⁴·M₄/180`) for `f` with a two-sided fourth derivative bounded by `M₄` on the interval;
  `f⁗` need not be continuous. Both reuse `Diana.Real.Quadrature`, and `make real` builds the Rocq
  proof.
- Flocq proves the Simpson binary64 theorems in `verification/rocq/theory/Float/Simpson.v`:
  SIMPSON-B1 (`finite_result`: a finite result implies finite `h`, samples and partial sums) and
  SIMPSON-B2 (`forward_error`: `|r − h·S′/3| ≤ γₚ₊₅·|h|·A/3 + (1 + u)·η/3 + η` for `(p + 5)·u < 1`,
  with `A` the Simpson-weighted absolute sum of the samples). `Diana.Float.Sum` gains `fdiv` with
  its value and finiteness lemmas, exact scaling by a power of two (`fmul_exact`), `gamma_mono`,
  and the addition step `add_step`; `fold_error` takes its absolute error term as a parameter, so
  a sum started from an exact `+0` carries none.
- VST proves SIMPSON-C2 (`Diana.VST.Simpson.body_diana_simpson`) against the committed AArch64
  macOS Clight AST `verification/clight/simpson_aarch64_macos.v`: for non-NULL `y` with an odd
  `n >= 3`, `diana_simpson` returns `DIANA_OK` and writes the Flocq model value exactly when it is
  finite, and otherwise returns `DIANA_ERR_ARG` with `*result` unchanged. Every Simpson theorem is
  now proved, so the full strict spec gate passes with both quadrature rules.
- Lean and Rocq prove the Euler error bounds EULER-A1 (`Diana.Real.Euler.local_error`, one step:
  `M₂·h²/2`) and EULER-A2 (`global_error`: `(M₂·h/(2L))·(e^{L·k·h} − 1)` after `k` steps) for
  `y′ = F(t, y)` with `F` L-Lipschitz in `y` and `‖y″‖ ≤ M₂`; `y″` need not be continuous. Lean
  states them for any real normed space, Rocq for vectors `nat → R` with the max norm
  (`Diana.Real.Vector`). The global bound comes from a discrete Grönwall lemma for any one-step
  method, `Diana.Real.OneStep.one_step_error` in both provers, which RK4 will reuse. `make real`
  builds the new Rocq modules.
- Flocq proves the Euler binary64 theorems in `verification/rocq/theory/Float/Euler.v`: EULER-B1
  (`finite_result`: a finite component implies finite `y_i`, `f_i`, `h` and product, so neither
  operation overflowed) and EULER-B2 (`forward_error`: `|r_i − (y_i + h·f_i)| ≤
  u·|y_i + h·f_i| + (1 + u)·(u·|h·f_i| + η)` per component).
- VST proves EULER-C2 (`Diana.VST.Euler.body_diana_euler_step`) against the committed AArch64
  macOS Clight AST `verification/clight/euler_aarch64_macos.v`: for non-NULL, disjoint `y`, `f`
  and `y_out` with `d >= 1`, `diana_euler_step` writes the Flocq model values and returns
  `DIANA_OK` exactly when all of them are finite, and otherwise returns `DIANA_ERR_ARG` with
  `y_out` unchanged. Every Euler theorem listed in `spec/euler.md` is now proved.

#### Tests and tooling

- `test/c/test_trapezoidal.c` covers every path of `diana_trapezoidal`, restoring 100% C line and
  branch coverage: NULL pointers, `n < 2`, exact results on affine data, the left-to-right
  summation order, overflow from finite samples, NaN and infinite samples and `h`, `h = 0`, and
  underflow to zero. `test/python/test_trapezoidal.py` checks the binding's buffer handling,
  bitwise agreement with a sequential binary64 evaluation (Hypothesis), the forward rounding-error
  bound against exact rational arithmetic, and second-order convergence against mpmath.
- `test/c/test_bisection.c` covers the last uncovered paths of the kernel and the wrapper, taking C
  line and branch coverage to 100%: the `diana_bisection_init` early `DIANA_OK` (bracket already
  within the tolerance, and a bracket so narrow that the midpoint rounds onto an endpoint, in both
  rounding directions), the `diana_bisection_step` stagnation exits on each side of the bracket
  update, a non-finite `fb`, and in `diana_bisection` a callback that returns a non-finite value at
  the midpoint plus the `iter == NULL` calls.
- `script/check_wheel.py` checks static and shared installed wheels in isolated environments;
  Python CI runs it. `test_install` checks the installed CMake consumer with a custom
  header directory and with a shared library, and gates releases.
- `script/check_commit.sh` checks commit history against the commit convention: no merge commit,
  a `<type>[(scope)]: <summary>` subject of at most 50 characters without an article, a message
  that is the subject and one `Signed-off-by` matching the committer, and an author date equal to
  the commit date. The new `pre-push` hook in `.git-hooks/` runs it on the commits the remote does
  not have, and the `style_git` CI job on the commits since the branch's previous pipeline (the
  merge request's commits in a merge request pipeline, otherwise the whole history when there is
  no previous pipeline).

### Changed

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
- The reusable parts of the trapezoidal proofs are separate modules, with the theorem statements
  unchanged: `Diana.Real.Quadrature` in Lean and Rocq (the mean-value bound against a boundary
  function, the clamped extension used for the fundamental theorem of calculus, and the sum of
  per-panel errors, `panel_error`) and `Diana.Float.Sum` in Rocq (`u`, `η`, `γₖ`, the rounding
  error lemmas, and the recursive-summation bound `fold_error`). `make real` builds
  `Real/Quadrature.v` before `Real/Trapezoidal.v`.
- The buffer checks of the array kernels' Python bindings are one helper,
  `diana_py_get_samples` in `python/ext/convert.c`, which names the argument in its messages and
  can request a writable buffer; `diana.trapezoidal` keeps its checks, their order and its
  messages.
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

[Unreleased]: https://gitlab.com/yhu1729/diana/-/compare/v0.3.0...main
[0.3.0]: https://gitlab.com/yhu1729/diana/-/compare/v0.2.0...v0.3.0
[0.2.0]: https://gitlab.com/yhu1729/diana/-/compare/v0.1.0...v0.2.0
[0.1.0]: https://gitlab.com/yhu1729/diana/-/tags/v0.1.0
