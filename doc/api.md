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

## Bisection (`diana/bisect.h`)

Reverse-communication form: the kernel uses no function pointer, and the caller evaluates `f` at
`s.x` between calls.

```c
diana_bisect_state s;
diana_status st = diana_bisect_init(&s, a, b, f(a), f(b), tol, max_iter);
while (st == DIANA_CONTINUE)
    st = diana_bisect_step(&s, f(s.x));
if (st == DIANA_OK)
    diana_bisect_result(&s, &root, &width);
```

| Field | Meaning |
|---|---|
| `a`, `b` | current bracket, `a <= b` |
| `fa`, `fb` | `f(a)`, `f(b)` |
| `x` | point at which the caller must evaluate `f` next (the midpoint) |
| `tol` | stop when `b - a <= tol`, `tol >= 0` |
| `iter` | steps performed so far |
| `max_iter` | step limit |

Invariant kept by every call (Frama-C WP, BIS-C2 in `spec/bisect.md`): `a <= b`,
`|a|, |b| <= DBL_MAX/2`, `fa` and `fb` finite, `tol >= 0`, and either `fa` and `fb` of strictly
opposite sign or `a == b` with `fa == fb == 0`; whenever the last status was `DIANA_CONTINUE`,
`a < x < b`. The kernel sets `x` to the binary64 midpoint `0.5 * (a + b)`; that this matches the
Flocq model is proved for the helper that computes it (BIS-C1) and for `diana_bisect_result`
(BIS-C5), not yet for `init`/`step`, whose verified guarantees are the WP contracts (BIS-C2).
A rejected call leaves the state unchanged (also BIS-C2): `init` returning `DIANA_ERR_ARG` or
`DIANA_ERR_BRACKET`, and `step` returning `DIANA_ERR_ARG`, write nothing to `*s`.

- `diana_bisect_init(s, a, b, fa, fb, tol, max_iter)` initialises the state from the bracket
  `[a, b]` and `fa = f(a)`, `fb = f(b)`. Returns `DIANA_CONTINUE` with `s->x` set to the first
  midpoint; `DIANA_OK` if the bracket already satisfies the tolerance, has no representable
  interior point, or `fa == 0` or `fb == 0`;
  `DIANA_ERR_ARG` on NULL, NaN or infinite input, `a > b`, `|a|` or `|b| > DBL_MAX/2`, `tol < 0`, or
  `max_iter == 0`; `DIANA_ERR_BRACKET` if `fa` and `fb` have the same strict sign.
- `diana_bisect_step(s, fx)` consumes `fx = f(s->x)` and halves the bracket: if `fx` and `fa` have
  the same strict sign the root is in `[x, b]`, otherwise in `[a, x]`. Returns `DIANA_CONTINUE` with
  a new `s->x`, `DIANA_OK` on convergence, or `DIANA_ERR_MAXITER`. Convergence also occurs when
  `fx == 0` or the midpoint equals an endpoint (adjacent doubles: no representable interior point
  remains). Returns `DIANA_ERR_ARG` for a NULL state or a non-finite `fx`.
- `diana_bisect_result(s, root, width)` reports the current estimate `root = 0.5 * (a + b)` and
  `width = b - a`. Either output may be NULL; a non-NULL output must not alias the state or the
  other output.

## Callback wrapper (`diana/wrapper.h`)

The wrappers loop over the verified reverse-communication kernels and are not verified (neither
VST nor Frama-C); the callback is a trust boundary.

- `diana_bisect(f, ctx, a, b, tol, max_iter, root, iter)` finds a root of `f` in `[a, b]` by
  bisection, with `f` of type `diana_bisect_fn`. It evaluates `f(a)`, then `f(b)`, then `f` once
  per step. On `DIANA_OK` or `DIANA_ERR_MAXITER`, `*root` holds the current estimate
  `0.5 * (a + b)`; on any other status it is not written. `*iter` (optional) receives the number of
  steps on every return (0 when the arguments or the bracket are rejected). The callback result
  must be finite.

# Python API

The package `diana` exposes each iterative kernel as a reverse-communication state object (for
example `diana.Bisect`) and, for convenience, as a function taking a Python callable (for example
`diana.bisect`). The callable loop runs in Python and is not part of the verified code. Docstrings
are available through `help()`.

`diana.bisect` converts `a` and `b` to `float` before evaluating `f`, so `f(a)` and `f(b)` are the
values at the binary64 endpoints the kernel brackets. The default `max_iter` of `diana.bisect` and
`diana.Bisect` is 2100, which covers the worst case of `tol = 0` (2098 steps, for a root at the
smallest subnormal in `[-DBL_MAX/2, DBL_MAX/2]`; measured and pinned by a test — BIS-B4 proves
termination but not this constant), so with default arguments `MaxIterError` is not expected. `max_iter` must be an integer that fits a C
`unsigned int` (`OverflowError` otherwise, `ValueError` for 0); `status_str` raises `OverflowError`
for a code outside the C `int` range.

`diana.__version__` is the version string of the linked C library, the same value `diana.version()`
returns.

`diana.bisect` raises `diana.BracketError` when `f(a)` and `f(b)` do not bracket a root, and
`diana.MaxIterError` when `max_iter` is reached first; the latter carries the attributes
`estimate`, `width` and `iter` (also its `args`, so it survives pickling across a process
boundary). The status constants `diana.OK`, `CONTINUE`, `ERR_ARG`, `ERR_BRACKET` and `ERR_MAXITER`
are the Python spellings of the `DIANA_*` codes above, as returned by `diana.Bisect.step`.

The CPython extension `diana._diana` is hand-written and has no NumPy dependency; array kernels
will use the buffer protocol. It uses single-phase module initialisation: the multi-phase slot table
stores a function pointer in a `void *`, which is not strict ISO C and fails `-Wpedantic -Werror` on
gcc.
