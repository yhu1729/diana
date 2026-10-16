# C API

Every public function returns `diana_status` and is declared in `include/diana/`; `diana/diana.h`
is the umbrella header.

After `cmake --install build --prefix <prefix>`, a CMake project links the library with

```cmake
find_package(diana 0.1 CONFIG REQUIRED)
target_link_libraries(app PRIVATE diana::diana)
```

(`-DCMAKE_PREFIX_PATH=<prefix>`). Before 1.0, a version request matches only the same minor
version.

## Status (`diana/status.h`)

| Code | Value | Meaning |
|---|---|---|
| `DIANA_OK` | 0 | converged or completed |
| `DIANA_CONTINUE` | 1 | reverse communication: evaluate at the requested point and call `step` again |
| `DIANA_ERR_ARG` | -1 | invalid argument: NULL, NaN, infinite, out of range |
| `DIANA_ERR_BRACKET` | -2 | `f(a)` and `f(b)` have the same strict sign |
| `DIANA_ERR_MAXITER` | -3 | iteration limit reached before the tolerance was met |

`diana_status_str(s)` returns a static, human-readable name for a status code and never returns
NULL. `diana_version()` returns `DIANA_VERSION_STRING` of the linked library.

## Bisection (`diana/bisection.h`)

Reverse-communication form: the kernel uses no function pointer, and the caller evaluates `f` at
`s.x` between calls.

```c
diana_bisection_state s;
diana_status st = diana_bisection_init(&s, a, b, f(a), f(b), tol, max_iter);
while (st == DIANA_CONTINUE)
    st = diana_bisection_step(&s, f(s.x));
if (st == DIANA_OK)
    diana_bisection_result(&s, &root, &width);
```

| Field | Meaning |
|---|---|
| `a`, `b` | current bracket, `a <= b` |
| `fa`, `fb` | `f(a)`, `f(b)` |
| `x` | point at which the caller must evaluate `f` next (the midpoint) |
| `tol` | stop when `b - a <= tol`, `tol >= 0` |
| `iter` | steps performed so far |
| `max_iter` | step limit |

Invariant kept by every call (Frama-C WP, BISECTION-C2 in `spec/bisection.md`): `a <= b`,
`|a|, |b| <= DBL_MAX/2`, `fa` and `fb` finite, `tol >= 0`, and either `fa` and `fb` of strictly
opposite sign or `a == b` with `fa == fb == 0`; whenever the last status was `DIANA_CONTINUE`,
`a < x < b`. The kernel sets `x` to the binary64 midpoint `0.5 * (a + b)`; that this matches the
Flocq model is proved for the helper that computes it (BISECTION-C1) and for
`diana_bisection_result` (BISECTION-C5), not yet for `init`/`step`, whose verified guarantees are
the WP contracts (BISECTION-C2). A rejected call leaves the state unchanged (also BISECTION-C2):
`init` returning `DIANA_ERR_ARG` or `DIANA_ERR_BRACKET`, and `step` returning `DIANA_ERR_ARG`, write
nothing to `*s`.

- `diana_bisection_init(s, a, b, fa, fb, tol, max_iter)` initialises the state from the bracket
  `[a, b]` and `fa = f(a)`, `fb = f(b)`. Returns `DIANA_CONTINUE` with `s->x` set to the first
  midpoint; `DIANA_OK` if the bracket already satisfies the tolerance, has no representable
  interior point, or `fa == 0` or `fb == 0`;
  `DIANA_ERR_ARG` on NULL, NaN or infinite input, `a > b`, `|a|` or `|b| > DBL_MAX/2`, `tol < 0`, or
  `max_iter == 0`; `DIANA_ERR_BRACKET` if `fa` and `fb` have the same strict sign.
- `diana_bisection_step(s, fx)` consumes `fx = f(s->x)` and halves the bracket: if `fx` and `fa`
  have the same strict sign the root is in `[x, b]`, otherwise in `[a, x]`. Returns `DIANA_CONTINUE`
  with a new `s->x`, `DIANA_OK` on convergence, or `DIANA_ERR_MAXITER`. Convergence also occurs when
  `fx == 0` or the midpoint equals an endpoint (adjacent doubles: no representable interior point
  remains). Returns `DIANA_ERR_ARG` for a NULL state or a non-finite `fx`.
- `diana_bisection_result(s, root, width)` reports the current estimate `root = 0.5 * (a + b)` and
  `width = b - a`. Either output may be NULL; a non-NULL output must not alias the state or the
  other output.

## Composite trapezoidal rule (`diana/trapezoidal.h`)

A function over tabulated samples: the caller evaluates `f` at the nodes. There is no callback
wrapper; Python calls the kernel as `diana.trapezoidal` (see the Python API).

- `diana_trapezoidal(y, n, h, result)` writes `h * (0.5 * (y[0] + y[n-1]) + y[1] + ... + y[n-2])` to
  `*result`, evaluated in binary64 in that order (`n - 1` panels of width `h`; a negative `h`
  integrates in the opposite direction). Returns `DIANA_OK` when the result is finite. Returns
  `DIANA_ERR_ARG`, without writing `*result`, for a NULL `y` or `result`, for `n < 2`, and when the
  result is not finite: a NaN or infinite sample or `h`, or an overflow anywhere in the sum. A
  finite result implies that no intermediate overflowed (TRAPEZOIDAL-B1 in `spec/trapezoidal.md`).
  `y[0 .. n-1]` is only read and must not overlap `*result`.

Frama-C WP proves memory safety, termination, the status cases and the finiteness of `*result` on
`DIANA_OK` (TRAPEZOIDAL-C1). For exact samples of an `f` whose second derivative is bounded by `M₂`
on `[a, b]`, the rule in exact arithmetic is within `(b − a)·h²·M₂/12` of the integral
(TRAPEZOIDAL-A2, proved in Lean and Rocq). The binary64 evaluation order above is within
`γₙ·|h|·A + (1 + γₙ₋₁)·|h|·η + η` of the exact rule whenever its result is finite, with
`A = |y[0] + y[n-1]|/2 + |y[1]| + ... + |y[n-2]|`, `γₖ = k·u/(1 − k·u)`, `u = 2⁻⁵³` and
`η = 2⁻¹⁰⁷⁵` (TRAPEZOIDAL-B2, Flocq); the bound is relative to `A`, not to the result, so it says
little under heavy cancellation. VST proves that the C computes exactly this binary64 value and returns
`DIANA_OK` exactly when it is finite, leaving `*result` unchanged otherwise (TRAPEZOIDAL-C2, for
non-NULL `y` with `n >= 2`).

## Composite Simpson rule (`diana/simpson.h`)

A function over tabulated samples, like the trapezoidal rule. There is no callback wrapper; Python
calls the kernel as `diana.simpson` (see the Python API).

- `diana_simpson(y, n, h, result)` writes `(h * s) / 3` to `*result`, with
  `s = ((y[0] + y[n-1]) + 4 * so) + 2 * se`, where `so = y[1] + y[3] + ... + y[n-2]` and
  `se = y[2] + y[4] + ... + y[n-3]` are each summed left to right from `+0`; every operation is
  binary64 in that order (`n - 1` panels of width `h`, an even number). Returns `DIANA_OK` when the
  result is finite. Returns `DIANA_ERR_ARG`, without writing `*result`, for a NULL `y` or `result`,
  for `n < 3` or an even `n`, and when the result is not finite: a NaN or infinite sample or `h`, or
  an overflow in any operation, including `h * s` when `(h * s) / 3` alone would be finite.
  `y[0 .. n-1]` is only read and must not overlap `*result`.

Frama-C WP proves memory safety, termination, the status cases and the finiteness of `*result` on
`DIANA_OK` (SIMPSON-C1). For exact samples of an `f` whose fourth derivative is bounded by `M₄` on
`[a, b]`, the rule in exact arithmetic is within `(b − a)·h⁴·M₄/180` of the integral (SIMPSON-A2,
proved in Lean and Rocq). The binary64 evaluation order above is within
`γₚ₊₅·|h|·A/3 + (1 + u)·η/3 + η` of the exact rule whenever its result is finite, with `p = (n − 1)/2`,
`A = |y[0] + y[n-1]| + 4·(|y[1]| + |y[3]| + ...) + 2·(|y[2]| + |y[4]| + ...)`,
`γₖ = k·u/(1 − k·u)`, `u = 2⁻⁵³` and `η = 2⁻¹⁰⁷⁵` (SIMPSON-B2, Flocq); like the trapezoidal bound it
is relative to `A`, not to the result. VST proves that the C computes exactly this binary64 value
and returns `DIANA_OK` exactly when it is finite, leaving `*result` unchanged otherwise
(SIMPSON-C2, for non-NULL `y` with an odd `n >= 3`).

## Explicit Euler step (`diana/euler.h`)

One step of the explicit Euler method on a vector of dimension `d`; the caller evaluates
`f = F(t, y)` and loops over the steps. There is no callback wrapper or Python binding yet.

- `diana_euler_step(y, f, d, h, y_out)` writes `y_out[i] = y[i] + h * f[i]` for
  `i = 0, ..., d-1`, the product rounded before the sum (no fused multiply-add). `y_out[0 .. d-1]`
  must not overlap `y[0 .. d-1]` or `f[0 .. d-1]`, which are only read. Returns `DIANA_OK` when
  every component is finite. Returns `DIANA_ERR_ARG`, without writing `y_out`, for a NULL `y`,
  `f` or `y_out`, for `d == 0`, and when any component is not finite: a NaN or infinite `y[i]`,
  `f[i]` or `h`, or an overflow in either operation. The kernel checks every component before it
  writes any, so a failure in the last one leaves `y_out` as it was.

Frama-C WP proves memory safety, termination, the status cases and that `y_out` is untouched on
`DIANA_ERR_ARG` (EULER-C1). For `y′ = F(t, y)` with `F` L-Lipschitz in `y` and `‖y″‖ ≤ M₂` in the max
norm, `k` exact Euler steps of size `h` from `y(t₀)` are within `(M₂·h/(2L))·(e^{L·k·h} − 1)` of
`y(t₀ + k·h)` (EULER-A2, proved in Lean and Rocq; one step is within `M₂·h²/2`, EULER-A1).
Each computed component is within `u·|y[i] + h·f[i]| + (1 + u)·(u·|h·f[i]| + η)` of the exact
`y[i] + h·f[i]` whenever it is finite, with `u = 2⁻⁵³` and `η = 2⁻¹⁰⁷⁵` (EULER-B2, Flocq).
VST proves that the C writes exactly these binary64 values and returns `DIANA_OK` exactly when all
of them are finite, leaving `y_out` unchanged otherwise (EULER-C2, for non-NULL, disjoint `y`, `f`
and `y_out` with `d >= 1`).

## Callback wrapper (`diana/wrapper.h`)

The wrappers loop over the verified reverse-communication kernels and are not verified (neither
VST nor Frama-C); the callback is a trust boundary.

- `diana_bisection(f, ctx, a, b, tol, max_iter, root, iter)` finds a root of `f` in `[a, b]` by
  bisection, with `f` of type `diana_bisection_fn`. It evaluates `f(a)`, then `f(b)`, then `f` once
  per step. On `DIANA_OK` or `DIANA_ERR_MAXITER`, `*root` holds the current estimate
  `0.5 * (a + b)`; on any other status it is not written. `*iter` (optional) receives the number of
  steps on every return (0 when the arguments or the bracket are rejected). The callback result
  must be finite.

# Python API

The package `diana` exposes each iterative kernel as a reverse-communication state object (for
example `diana.Bisection`) and, for convenience, as a function taking a Python callable (for example
`diana.bisection`). The callable loop runs in Python and is not part of the verified code.
Docstrings are available through `help()`.

`diana.bisection` converts `a` and `b` to `float` before evaluating `f`, so `f(a)` and `f(b)` are
the values at the binary64 endpoints the kernel brackets. The default `max_iter` of
`diana.bisection` and `diana.Bisection` is 2100, which covers the worst case of `tol = 0` (2098
steps, for a root at the smallest subnormal in `[-DBL_MAX/2, DBL_MAX/2]`; measured and pinned by a
test — BISECTION-B4 proves termination but not this constant), so with default arguments
`MaxIterError` is not expected. `max_iter` must be an integer that fits a C `unsigned int`
(`OverflowError` otherwise, `ValueError` for 0); `status_str` raises `OverflowError` for a code
outside the C `int` range.

`diana.__version__` is the version string of the linked C library, the same value `diana.version()`
returns.

A `diana.Bisection` allocated directly with `__new__` has status `ERR_ARG` until `__init__`
succeeds; `step()` and `result()` raise `RuntimeError` before that. A failed `__init__` leaves the
existing state and status unchanged, so a previously initialized object remains usable.

`diana.bisection` raises `diana.BracketError` when `f(a)` and `f(b)` do not bracket a root, and
`diana.MaxIterError` when `max_iter` is reached first; the latter carries the attributes
`estimate`, `width` and `iter` (also its `args`, so it survives pickling across a process
boundary). The status constants `diana.OK`, `CONTINUE`, `ERR_ARG`, `ERR_BRACKET` and `ERR_MAXITER`
are the Python spellings of the `DIANA_*` codes above, as returned by `diana.Bisection.step`.

`diana.trapezoidal(y, h)` returns the composite trapezoidal rule of `diana_trapezoidal` as a
`float`, with the same operation order. A `y` that supports the buffer protocol (a NumPy `float64`
array, `array.array("d")`, a `memoryview`, a ctypes `c_double` array) is read in place, without a
copy, and must hold native-endian float64 (format `d`, optionally prefixed by `@`, `=`, or the
native byte-order character) in one dimension, C-contiguous and aligned for `double`. The checks run
in this order: another element type raises `TypeError`; another dimension, fewer than two samples,
a non-contiguous view, or a misaligned start raise `ValueError`. Any other iterable of numbers is
first copied into an `array.array("d")`, which converts each element through `__float__` (or
`__index__`, rounding an integer to the nearest double) and raises its own `TypeError` or
`OverflowError`. A non-finite result (`DIANA_ERR_ARG` in C) raises
`ValueError`.

`diana.simpson(y, h)` returns the composite Simpson rule of `diana_simpson` as a `float`, with the
same operation order, and takes `y` exactly as `diana.trapezoidal` does, with the same checks in the
same order, except that it needs at least three samples; after them, an even number of samples
raises `ValueError`. A non-finite result raises `ValueError`.

The CPython extension `diana._diana` is hand-written and has no NumPy dependency; array kernels
use the buffer protocol. It uses single-phase module initialisation: the multi-phase slot table
stores a function pointer in a `void *`, which is not strict ISO C and fails `-Wpedantic -Werror` on
gcc.
