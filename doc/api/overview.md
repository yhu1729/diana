# API overview

What every kernel shares. Each method has its own page, with its C functions, its callback wrapper
if any, and its Python functions: [bisection](bisection.md),
[composite trapezoidal rule](trapezoidal.md), [composite Simpson rule](simpson.md),
[explicit Euler step](euler.md), and [Newton's method](newton.md).

## C

Every public function returns `diana_status` and is declared in `include/diana/`; `diana/diana.h`
is the umbrella header.

### Linking

After `cmake --install build --prefix <prefix>`, a CMake project links the library with
`find_package(diana)` and the target `diana::diana` (`-DCMAKE_PREFIX_PATH=<prefix>`). Before 1.0,
a version request matches only the same minor version. A complete consumer is two files.
`CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.25)
project(app LANGUAGES C)

find_package(diana 0.2 CONFIG REQUIRED)

add_executable(app main.c)
target_link_libraries(app PRIVATE diana::diana)
```

`main.c`, which integrates five samples of `x²` on `[0, 1]`:

```c
#include <stdio.h>

#include <diana/diana.h>

int main(void) {
  const double y[] = {0.0, 1.0, 4.0, 9.0, 16.0};
  double area;
  diana_status st = diana_trapezoidal(y, 5, 0.25, &area);
  if (st != DIANA_OK) {
    fprintf(stderr, "diana_trapezoidal: %s\n", diana_status_str(st));
    return 1;
  }
  printf("area %g\n", area);
  return 0;
}
```

Build it against the installed library:

```bash
cmake -S . -B build -DCMAKE_PREFIX_PATH=<prefix>
cmake --build build
./build/app
```

```text
area 5.5
```

### Status

`diana/status.h`:

| Code | Value | Meaning |
|---|---|---|
| `DIANA_OK` | 0 | converged or completed |
| `DIANA_CONTINUE` | 1 | reverse communication: evaluate at the requested point and call `step` again |
| `DIANA_ERR_ARG` | -1 | invalid argument: NULL, NaN, infinite, out of range |
| `DIANA_ERR_BRACKET` | -2 | `f(a)` and `f(b)` have the same strict sign |
| `DIANA_ERR_MAXITER` | -3 | iteration limit reached before the tolerance was met |
| `DIANA_ERR_SINGULAR` | -4 | the derivative (Newton) is zero, so the step is undefined; the state is unchanged |

`diana_status_str(s)` returns a static, human-readable name for a status code and never returns
NULL. `diana_version()` returns `DIANA_VERSION_STRING` of the linked library.

Check every status; a failed call writes no output:

```c
const double y[] = {1.0}; /* one sample: no panel */
double area;
diana_status st = diana_trapezoidal(y, 1, 0.5, &area);
if (st != DIANA_OK) {
  fprintf(stderr, "%s\n", diana_status_str(st));
}
```

```text
invalid argument
```

### Callback wrapper

The wrappers in `diana/wrapper.h` loop over the verified reverse-communication kernels and are not
verified (neither VST nor Frama-C); the callback is a trust boundary. Each is described with its
kernel: `diana_bisection` under [bisection](bisection.md), `diana_euler` under
[explicit Euler step](euler.md), `diana_newton` under [Newton's method](newton.md).

## Python

The package `diana` exposes each iterative kernel as a reverse-communication state object
(`diana.Bisection`, `diana.Newton`) and, for convenience, as a function taking a Python callable
(`diana.bisection`, `diana.newton`). The callable loop runs in Python and is not part of the
verified code.
Docstrings are available through `help()`.

`diana.__version__` is the version string of the linked C library, the same value `diana.version()`
returns.

The status constants `diana.OK`, `CONTINUE`, `ERR_ARG`, `ERR_BRACKET`, `ERR_MAXITER` and
`ERR_SINGULAR` are the Python spellings of the `DIANA_*` codes above, as returned by
`diana.Bisection.step` and `diana.Newton.step`; `status_str` raises `OverflowError` for a code
outside the C `int` range.

```python
>>> import diana
>>> diana.ERR_BRACKET
-2
>>> diana.status_str(diana.ERR_BRACKET)
'no sign change in bracket'
```

A C error status becomes an exception: `DIANA_ERR_ARG` raises `ValueError`, `DIANA_ERR_BRACKET`
raises `diana.BracketError` (a `ValueError`), `DIANA_ERR_SINGULAR` raises `diana.SingularError`
(a `ValueError`), and `DIANA_ERR_MAXITER` in `diana.bisection` and `diana.newton` raises
`diana.MaxIterError` (a `RuntimeError`).

```python
>>> try:
...     diana.trapezoidal([1.0, float("inf")], 0.5)
... except ValueError as e:
...     print(e)
trapezoidal result is not finite
```

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

```python
>>> import array
>>> import numpy as np
>>> import diana
>>> diana.trapezoidal([0, 1, 4, 9, 16], 0.25)  # copied into array.array("d")
5.5
>>> diana.trapezoidal(array.array("d", [0, 1, 4, 9, 16]), 0.25)  # read in place
5.5
>>> diana.trapezoidal(np.arange(5.0) ** 2, 0.25)  # read in place
5.5
```

A buffer of another element type or layout is rejected rather than converted; convert it first:

```python
>>> x = np.arange(5, dtype=np.float32)
>>> diana.trapezoidal(x, 0.25)
Traceback (most recent call last):
  ...
TypeError: y must be a buffer of native float64 (format 'd'), not format 'f'
>>> diana.trapezoidal(x.astype(np.float64), 0.25)
2.0
>>> v = np.arange(10.0)[::2]
>>> diana.trapezoidal(v, 0.25)
Traceback (most recent call last):
  ...
ValueError: y must be C-contiguous
>>> diana.trapezoidal(np.ascontiguousarray(v), 0.25)
4.0
```

### Extension

The CPython extension `diana._diana` is hand-written and has no NumPy dependency; array kernels
use the buffer protocol. It uses single-phase module initialisation: the multi-phase slot table
stores a function pointer in a `void *`, which is not strict ISO C and fails `-Wpedantic -Werror` on
gcc.
