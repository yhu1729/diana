# Composite trapezoidal rule

The composite trapezoidal rule approximates `∫ f` over `[a, b]` from `n` equally spaced samples
`y[i] = f(a + i·h)`, `h = (b − a)/(n − 1)`, by joining them with straight lines. Its error is
`O(h²)` for a smooth `f`. You evaluate `f` at the nodes; the kernel only combines the samples.
Shared conventions are in the [API overview](overview.md).

## C

`#include <diana/trapezoidal.h>`.

- `diana_trapezoidal(y, n, h, &result)` writes
  `h·(y[0]/2 + y[1] + … + y[n−2] + y[n−1]/2)` to `result`, for `n >= 2` samples spaced `h` apart
  (a negative `h` integrates in the opposite direction). It returns `DIANA_OK`; `DIANA_ERR_ARG`
  for a `NULL` pointer, `n < 2`, or a NaN or infinite sample or `h`; or `DIANA_ERR_OVERFLOW` when
  every input is finite and the result overflows. Neither error writes `result`.

The kernel halves the endpoint sum first, adds the interior samples left to right, and multiplies by
`h` last, each operation rounded to binary64. `y` is only read and must not overlap `result`.
Integrating `x²` on `[0, 1]` from 101 samples; since `f″ = 2` is constant, the error equals the
theoretical bound `(b − a)·h²·max|f″|/12 = 1.67e-5`:

```c
#include <stdio.h>

#include <diana/trapezoidal.h>

#define N 101

int main(void) {
  const double a = 0.0, b = 1.0, h = (b - a) / (N - 1);
  double y[N], area;
  for (size_t i = 0; i < N; ++i) {
    double x = a + (double)i * h;
    y[i] = x * x;
  }
  diana_status st = diana_trapezoidal(y, N, h, &area);
  if (st != DIANA_OK) {
    fprintf(stderr, "trapezoidal: %s\n", diana_status_str(st));
    return 1;
  }
  printf("%.15f (error %.2e)\n", area, area - 1.0 / 3.0);
  return 0;
}
```

```text
0.333350000000000 (error 1.67e-05)
```

## Python

`diana.trapezoidal(y, h)` returns the same value as a `float`. `y` is an
[array argument](overview.md#array-arguments) of at least two samples; a NaN or infinite sample
or `h` raises `ValueError`, and an overflow `diana.FloatOverflowError`.

```python
>>> import math
>>> import diana
>>> n = 101
>>> h = math.pi / (n - 1)
>>> diana.trapezoidal([math.sin(i * h) for i in range(n)], h)  # exact: 2
1.9998355038874436
>>> diana.trapezoidal([0.0, 1.0, 4.0], -1.0)  # negative h: opposite direction
-3.0
>>> diana.trapezoidal([1.0, float("nan")], 0.5)
Traceback (most recent call last):
  ...
ValueError: trapezoidal input is not finite: a sample or h
```

A NumPy `float64` array is read in place:

```python
>>> import numpy as np
>>> x = np.linspace(0.0, 1.0, 101)
>>> diana.trapezoidal(np.exp(x), 0.01)  # exact: e - 1 = 1.718281828459045
1.718296147450417
```

## Guarantees

Proved in Lean and Rocq: for exact samples of an `f` with `|f″| <= M₂`, the rule is within
`(b − a)·h²·M₂/12` of the integral. Proved in Rocq with Flocq: the binary64 evaluation is within a
rounding bound proportional to `n·u·|h|·Σ|y[i]|` (`u = 2⁻⁵³`) of the exact rule, and a finite
result means no intermediate step overflowed. Proved of the C code: VST shows that it computes
exactly that binary64 value, and Frama-C that it is memory-safe and free of undefined behaviour.
The rounding bound is relative to the sum of magnitudes, so it says little when the samples
cancel. Theorems: `spec/trapezoidal.md`; status: the
[verification report](../verification/report.md).

## Technical notes

[API-013](../../note/api/API-013.md) evaluation order and exits,
[API-036](../../note/api/API-036.md) non-finite input versus overflow,
[PROOF-003](../../note/proof/PROOF-003.md) what is proved, with the exact bounds.
