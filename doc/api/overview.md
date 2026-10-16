# API overview

What every kernel shares. Each method has its own page, with its C functions, its callback wrapper
if any, and its Python functions: [bisection](bisection.md),
[composite trapezoidal rule](trapezoidal.md), [composite Simpson rule](simpson.md), and
[explicit Euler step](euler.md).

## C

Every public function returns `diana_status` and is declared in `include/diana/`; `diana/diana.h`
is the umbrella header.

After `cmake --install build --prefix <prefix>`, a CMake project links the library with

```cmake
find_package(diana 0.2 CONFIG REQUIRED)
target_link_libraries(app PRIVATE diana::diana)
```

(`-DCMAKE_PREFIX_PATH=<prefix>`). Before 1.0, a version request matches only the same minor
version.

### Status

`diana/status.h`:

| Code | Value | Meaning |
|---|---|---|
| `DIANA_OK` | 0 | converged or completed |
| `DIANA_CONTINUE` | 1 | reverse communication: evaluate at the requested point and call `step` again |
| `DIANA_ERR_ARG` | -1 | invalid argument: NULL, NaN, infinite, out of range |
| `DIANA_ERR_BRACKET` | -2 | `f(a)` and `f(b)` have the same strict sign |
| `DIANA_ERR_MAXITER` | -3 | iteration limit reached before the tolerance was met |

`diana_status_str(s)` returns a static, human-readable name for a status code and never returns
NULL. `diana_version()` returns `DIANA_VERSION_STRING` of the linked library.

### Callback wrapper

The wrappers in `diana/wrapper.h` loop over the verified reverse-communication kernels and are not
verified (neither VST nor Frama-C); the callback is a trust boundary. Each is described with its
kernel: `diana_bisection` under [bisection](bisection.md), `diana_euler` under
[explicit Euler step](euler.md).

## Python

The package `diana` exposes each iterative kernel as a reverse-communication state object (for
example `diana.Bisection`) and, for convenience, as a function taking a Python callable (for example
`diana.bisection`). The callable loop runs in Python and is not part of the verified code.
Docstrings are available through `help()`.

`diana.__version__` is the version string of the linked C library, the same value `diana.version()`
returns.

The status constants `diana.OK`, `CONTINUE`, `ERR_ARG`, `ERR_BRACKET` and `ERR_MAXITER` are the
Python spellings of the `DIANA_*` codes above, as returned by `diana.Bisection.step`; `status_str`
raises `OverflowError` for a code outside the C `int` range.

### Array argument

An array argument (`y` of `diana.trapezoidal` and `diana.simpson`, `y` and `f` of
`diana.euler_step`) that supports the buffer protocol (a NumPy `float64` array, `array.array("d")`,
a `memoryview`, a ctypes `c_double` array) is read in place, without a copy, and must hold
native-endian float64 (format `d`, optionally prefixed by `@`, `=`, or the native byte-order
character) in one dimension, C-contiguous and aligned for `double`. The checks run in this order:
another element type raises `TypeError`; another dimension, fewer samples than the function needs,
a non-contiguous view, or a misaligned start raise `ValueError`. Any other iterable of numbers is
first copied into an `array.array("d")`, which converts each element through `__float__` (or
`__index__`, rounding an integer to the nearest double) and raises its own `TypeError` or
`OverflowError`.

### Extension

The CPython extension `diana._diana` is hand-written and has no NumPy dependency; array kernels
use the buffer protocol. It uses single-phase module initialisation: the multi-phase slot table
stores a function pointer in a `void *`, which is not strict ISO C and fails `-Wpedantic -Werror` on
gcc.
