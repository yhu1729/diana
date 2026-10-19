# API overview

Diana has a C API (`include/diana/`) and a Python package (`import diana`) over the same C
kernels. This page covers what every method shares. Each method has its own page:
[bisection](bisection.md), [Newton's method](newton.md),
[composite trapezoidal rule](trapezoidal.md), [composite Simpson rule](simpson.md),
[explicit Euler step](euler.md), [classical Runge–Kutta step](rk4.md),
[Cholesky factorization](cholesky.md), [forward and transpose substitution](substitution.md),
[LU factorization](lu.md), [LU solve](lu_solve.md) and [vector norms](norm.md).

## Floating-point environment

The guarantees assume IEEE binary64 arithmetic with round-to-nearest-even, gradual underflow (no
flush-to-zero or denormals-are-zero mode) and floating-point traps disabled, on every thread that
calls Diana. A process starts that way on Linux and macOS, but other code in it can change them: on
x86-64, for example, objects linked by GCC with `-ffast-math` turn on flush-to-zero. Diana neither
checks nor changes these settings, so a program that changes them, or a callback that does, voids
the guarantees.

## C

### Headers and linking

`#include <diana/diana.h>` declares everything; each method also has its own header, such as
`<diana/bisection.h>`. After `cmake --install build --prefix <prefix>`, a CMake project links the
target `diana::diana`. A complete consumer is two files. `CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.25)
project(app LANGUAGES C)

find_package(diana 1.0 CONFIG REQUIRED)

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

`find_package` accepts any release with the same major version that is not older than the one
requested.

### Status codes

Every function returns a `diana_status` (`diana/status.h`), except `diana_status_str` and
`diana_version`, which return strings.

| Code | Value | Meaning |
|---|---|---|
| `DIANA_OK` | 0 | finished |
| `DIANA_CONTINUE` | 1 | evaluate the function at the requested point and call `step` again |
| `DIANA_ERR_ARG` | -1 | invalid argument, or an input that is NaN or infinite |
| `DIANA_ERR_BRACKET` | -2 | bisection: `f(a)` and `f(b)` have the same sign |
| `DIANA_ERR_MAXITER` | -3 | iteration limit reached before convergence |
| `DIANA_ERR_SINGULAR` | -4 | Newton's method: zero derivative; Cholesky: a pivot that is not positive; substitution: a zero diagonal entry; LU: a zero pivot column; LU solve: a zero diagonal entry of `U` |
| `DIANA_ERR_OVERFLOW` | -5 | every input is finite, but a computed value overflows |
| `DIANA_ERR_CALLBACK` | -6 | an ODE wrapper's callback returned non-zero |

`diana_status_str(st)` returns a short message for a code, and `diana_version()` the version of
the linked library (the header defines `DIANA_VERSION_STRING` and its parts).

A call that fails with `DIANA_ERR_ARG`, `DIANA_ERR_BRACKET`, `DIANA_ERR_SINGULAR` or
`DIANA_ERR_OVERFLOW` changes no output and no state, with four exceptions, where each output entry
needs the ones before it: the Cholesky factorization has already written part of its output when it
finds a pivot that is not positive, forward and transpose substitution and the LU solve when an
entry of the solution overflows, and the LU factorization when it finds a zero pivot column or an
overflowing update. `DIANA_ERR_ARG` never writes anything. After `DIANA_ERR_MAXITER` and
`DIANA_ERR_CALLBACK` the state holds the progress made so far. Check every status:

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

### Kernels and callback wrappers

The verified kernels never call your code. The iterative methods (bisection, Newton) are state
machines: you evaluate the function at the point the state asks for and pass the value back,
which leaves you free to log, stop early, or evaluate the function elsewhere. The state's `status`
field says whether the run goes on, and `step` rejects a finished state with `DIANA_ERR_ARG`. The
ODE steps take slopes you have computed. All take caller-owned memory and allocate nothing.

For convenience, each iterative and ODE method also has a wrapper that runs the loop over a C
callback with a `void *ctx` argument for its parameters: `diana_bisection`, `diana_newton`,
`diana_euler` and `diana_rk4`. The wrappers are tested but not formally verified.

## Python

The package mirrors the C API:

- `diana.Bisection` and `diana.Newton` are the state machines, and `diana.bisection` and
  `diana.newton` run them over a Python callable.
- `diana.trapezoidal`, `diana.simpson`, `diana.euler_step`, `diana.rk4_stage` and
  `diana.rk4_step` call the array kernels, and `diana.euler` and `diana.rk4` loop over a
  callable.
- `diana.version()` (also `diana.__version__`), `diana.status_str` and the constants `diana.OK`,
  `CONTINUE`, `ERR_ARG`, `ERR_BRACKET`, `ERR_MAXITER`, `ERR_SINGULAR`, `ERR_OVERFLOW` and
  `ERR_CALLBACK` (only the C wrappers return it; Python callables raise their own exceptions).

Every function has a docstring (`help(diana.bisection)`).

```python
>>> import diana
>>> diana.ERR_BRACKET
-2
>>> diana.status_str(diana.ERR_BRACKET)
'no sign change in bracket'
```

### Exceptions

An error status becomes an exception:

| C status | Python exception |
|---|---|
| `DIANA_ERR_ARG` | `ValueError` (`TypeError` for an argument of the wrong type) |
| `DIANA_ERR_BRACKET` | `diana.BracketError`, a `ValueError` |
| `DIANA_ERR_SINGULAR` | `diana.SingularError`, a `ValueError` |
| `DIANA_ERR_OVERFLOW` | `diana.FloatOverflowError`, both a `ValueError` and an `OverflowError` |
| `DIANA_ERR_MAXITER` | `diana.MaxIterError`, a `RuntimeError`, raised by `diana.bisection` and `diana.newton` |

```python
>>> try:
...     diana.trapezoidal([1.0, float("inf")], 0.5)
... except ValueError as e:
...     print(e)
trapezoidal input is not finite: a sample or h
```

### Array arguments

An array argument accepts any iterable of numbers. A buffer of native `float64` values — a NumPy
array, an `array.array("d")`, a `memoryview` — that is one-dimensional and contiguous is read in
place without a copy; anything else iterable is copied first.

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

A buffer of another element type or layout is rejected rather than silently converted; convert
it first:

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

The extension module has no NumPy dependency, and it supports one interpreter per process (no
subinterpreters).

## Technical notes

[API-001](../../note/api/API-001.md) floating-point environment,
[API-002](../../note/api/API-002.md) status codes,
[API-003](../../note/api/API-003.md) what a failed call writes,
[API-036](../../note/api/API-036.md) non-finite input versus overflow,
[API-004](../../note/api/API-004.md) output pointers and overlap,
[API-005](../../note/api/API-005.md) CMake package,
[API-006](../../note/api/API-006.md) callback wrappers,
[API-020](../../note/api/API-020.md) array arguments,
[API-021](../../note/api/API-021.md) scalar arguments,
[API-022](../../note/api/API-022.md) exceptions,
[PYTHON-003](../../note/python/PYTHON-003.md) one interpreter per process.
