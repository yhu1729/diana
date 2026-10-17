# Composite Simpson rule

The composite Simpson rule approximates `∫ f` over `[a, b]` from an odd number `n` of equally
spaced samples `y[i] = f(a + i·h)` by fitting a parabola through each consecutive triple. Its
error is `O(h⁴)` for a smooth `f`, and it is exact for cubics. Like the
[trapezoidal rule](trapezoidal.md), the kernel only combines samples you have evaluated. Shared
conventions are in the [API overview](overview.md).

## C

`#include <diana/simpson.h>`.

- `diana_simpson(y, n, h, &result)` writes
  `(h/3)·(y[0] + 4·y[1] + 2·y[2] + 4·y[3] + … + 4·y[n−2] + y[n−1])` to `result`, for an odd
  `n >= 3` samples spaced `h` apart. It returns `DIANA_OK`, or `DIANA_ERR_ARG` without writing
  `result` for a `NULL` pointer, `n < 3` or an even `n`, or a result that is not finite: a NaN or
  infinite sample or `h`, or an overflow in any intermediate step.

The kernel sums the odd and the even interior samples separately, left to right, then forms
`((y[0] + y[n−1]) + 4·odd) + 2·even`, multiplies by `h` and divides by 3, each operation rounded
to binary64. `y` is only read and must not overlap `result`. Integrating `x³` on `[0, 1]` from
101 samples: the rule is exact for a cubic, and here no rounding error remains either; an even
count is rejected:

```c
#include <stdio.h>

#include <diana/simpson.h>

#define N 101

int main(void) {
  const double a = 0.0, b = 1.0, h = (b - a) / (N - 1);
  double y[N], area;
  for (size_t i = 0; i < N; ++i) {
    double x = a + (double)i * h;
    y[i] = x * x * x;
  }
  diana_status st = diana_simpson(y, N, h, &area);
  if (st != DIANA_OK) {
    fprintf(stderr, "simpson: %s\n", diana_status_str(st));
    return 1;
  }
  printf("%.15f (error %.2e)\n", area, area - 0.25);
  st = diana_simpson(y, N - 1, h, &area);
  printf("even n: %s\n", diana_status_str(st));
  return 0;
}
```

```text
0.250000000000000 (error 0.00e+00)
even n: invalid argument
```

## Python

`diana.simpson(y, h)` returns the same value as a `float`. `y` is an
[array argument](overview.md#array-arguments) of at least three samples; an even number of
samples or a non-finite result raises `ValueError`. On the samples of the
[trapezoidal examples](trapezoidal.md#python), the errors drop from `1.6e-4` and `1.4e-5` to
`1.1e-8` and `9.5e-11`:

```python
>>> import math
>>> import diana
>>> n = 101
>>> h = math.pi / (n - 1)
>>> diana.simpson([math.sin(i * h) for i in range(n)], h)  # exact: 2
2.000000010824504
>>> import numpy as np
>>> x = np.linspace(0.0, 1.0, 101)
>>> diana.simpson(np.exp(x), 0.01)  # exact: e - 1 = 1.718281828459045
1.7182818285545045
>>> diana.simpson([0.0, 1.0, 4.0, 9.0], 1.0)
Traceback (most recent call last):
  ...
ValueError: y must have an odd number of samples
```

## Guarantees

Proved in Lean and Rocq: for exact samples of an `f` with `|f⁗| <= M₄`, the rule is within
`(b − a)·h⁴·M₄/180` of the integral. Proved in Rocq with Flocq: the binary64 evaluation is within
a rounding bound proportional to `n·u·|h|` times the weighted sum of `|y[i]|` (`u = 2⁻⁵³`) of the
exact rule, and a finite result means no intermediate step overflowed. Proved of the C code: VST
shows that it computes exactly that binary64 value, and Frama-C that it is memory-safe and free
of undefined behaviour. Theorems: `spec/simpson.md`; status: the
[verification report](../verification/report.md).

## Technical notes

[API-014](../../note/api/API-014.md) evaluation order and exits,
[PROOF-004](../../note/proof/PROOF-004.md) what is proved, with the exact bounds.
