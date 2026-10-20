# Axpy

The update `y ← a·x + y` of a vector by a multiple of another, in place: the `axpy` of the BLAS,
over `n` doubles. It is the one Diana kernel that writes over an input, so a loop that
accumulates into a vector needs no second buffer. Shared conventions are in the
[API overview](overview.md).

## C

`#include <diana/axpy.h>`.

- `diana_axpy(a, x, n, y)` writes `y[i] = y[i] + a·x[i]` for `i < n`, the product rounded
  before the sum (no fused multiply-add). It returns `DIANA_OK`; `DIANA_ERR_ARG` for a `NULL`
  pointer or a NaN or infinite `a`, `x[i]` or `y[i]`; or `DIANA_ERR_OVERFLOW` when every input is
  finite and a component overflows. It checks every component before writing any, so a failure
  leaves `y` as it was. `n = 0` is allowed and does nothing, though `a` is still checked.

`x` is only read and must not overlap `y`. The out-of-place form of the same update is
`diana_euler_step(y, x, n, a, y_out)`, which computes the same bits into a separate buffer; with
`diana_axpy` the Euler loop of the [Euler page](euler.md) keeps a single state vector:

```c
#include <stdio.h>

#include <diana/axpy.h>

#define NSTEP 1000

static void rotate(const double *y, double *dy) {
  dy[0] = y[1];
  dy[1] = -y[0];
}

int main(void) {
  double y[2] = {0.0, 1.0}, f[2];
  const double h = 1.0 / NSTEP;
  for (unsigned k = 0; k < NSTEP; ++k) {
    rotate(y, f);
    diana_status st = diana_axpy(h, f, 2, y);
    if (st != DIANA_OK) {
      fprintf(stderr, "step %u: %s\n", k, diana_status_str(st));
      return 1;
    }
  }
  printf("y(1) = (%.6f, %.6f)\n", y[0], y[1]);
  return 0;
}
```

```text
y(1) = (0.841892, 0.540573)
```

## Python

`diana.axpy(a, x, y)` updates `y` in place and returns `None`. `y` must be a writable
[array argument](overview.md#array-arguments), such as a NumPy `float64` array or an
`array.array("d")`; `x` is any array argument of the same length, empty included. Lengths that
differ, an overlap of `y` with `x`, and a NaN or infinite input raise `ValueError`; an overflow
raises `diana.FloatOverflowError`, and `y` is then unchanged.

```python
>>> import diana
>>> from array import array
>>> y = array("d", [1.0, 2.0, 3.0])
>>> diana.axpy(0.5, [10.0, 20.0, 30.0], y)
>>> y
array('d', [6.0, 12.0, 18.0])
>>> diana.axpy(-0.5, [10.0, 20.0, 30.0], y)  # exact here, so it undoes the update
>>> y
array('d', [1.0, 2.0, 3.0])
>>> diana.axpy(2.0, [1.7976931348623157e308], y[:1])
Traceback (most recent call last):
  ...
diana._diana.FloatOverflowError: axpy result overflows
>>> diana.axpy(float("nan"), [], array("d"))
Traceback (most recent call last):
  ...
ValueError: axpy input is not finite: a, x or y
```

A NumPy array is updated in place, a view included:

```python
>>> import numpy as np
>>> z = np.zeros(4)
>>> diana.axpy(2.0, np.arange(3.0), z[1:])
>>> z
array([0., 0., 2., 4.])
```

## Guarantees

Proved in Lean and Rocq: `‖a·x + y‖ ≤ |a|·‖x‖ + ‖y‖` in each of the three norms, two updates
along the same `x` add their coefficients, and the update by `−a` undoes the update by `a`.
Proved in Rocq with Flocq: a finite component certifies that `a`, `x[i]`, `y[i]` and the product
are finite, and each component is within `u·|a·x[i] + y[i]| + (1 + u)·(u·|a·x[i]| + 2⁻¹⁰⁷⁵)` of
the exact value, `u = 2⁻⁵³`, the Euler-step bound with `a` as the step. Proved of the C code: VST
shows that the kernel computes exactly those binary64 values over `y` and returns each status
exactly when the model says so, and Frama-C that it is memory-safe and free of undefined
behaviour, with `y` untouched on every error. Theorems: `spec/axpy.md`; status: the
[verification report](../verification/report.md).

## Technical notes

[API-039](../../note/api/API-039.md) evaluation order and exits,
[API-040](../../note/api/API-040.md) the Python function,
[PROOF-014](../../note/proof/PROOF-014.md) what is proved, with the exact bound,
[KERNEL-002](../../note/kernel/KERNEL-002.md) the two-pass check that leaves `y` untouched.
