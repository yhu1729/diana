# Vector norms

The 1-norm `Σ|x[i]|`, the Euclidean norm `√(Σ x[i]²)` and the maximum norm `max|x[i]|` of a
vector of `n` doubles. The Euclidean norm scales by the largest magnitude, so it overflows only
when the norm itself is near `DBL_MAX`, and a nonzero vector never gets norm 0. Shared
conventions are in the [API overview](overview.md).

## C

`#include <diana/norm.h>`.

- `diana_norm_1(x, n, &result)` writes `|x[0]| + … + |x[n−1]|`, added left to right.
- `diana_norm_2(x, n, &result)` writes `√(x[0]² + … + x[n−1]²)`, computed as `m·√s` with `m`
  the largest `|x[i]|` and `s = 1 + Σ (x[i]/m)²` over the other entries.
- `diana_norm_inf(x, n, &result)` writes `max |x[i]|`, exactly.

Each returns `DIANA_OK`; `DIANA_ERR_ARG` for a `NULL` pointer or a NaN or infinite entry; or,
for the 1- and 2-norms, `DIANA_ERR_OVERFLOW` when every entry is finite and the result
overflows. No error writes `result`. `n = 0` is allowed and gives `+0`, as does any vector of
zeros. `x` is only read and must not overlap `result`.

The squares of the entries below would overflow a naive `sqrt(Σ x[i]²)`:

```c
#include <stdio.h>

#include <diana/norm.h>

int main(void) {
  /* the squares 9e400 and 16e400 overflow, the norms do not */
  const double x[3] = {3e200, -4e200, 1e-300};
  double sum, euclid, max;
  if (diana_norm_1(x, 3, &sum) != DIANA_OK ||
      diana_norm_2(x, 3, &euclid) != DIANA_OK ||
      diana_norm_inf(x, 3, &max) != DIANA_OK) {
    fprintf(stderr, "norm failed\n");
    return 1;
  }
  printf("%g %g %g\n", sum, euclid, max);
  return 0;
}
```

```text
7e+200 5e+200 4e+200
```

## Python

`diana.norm_1(x)`, `diana.norm_2(x)` and `diana.norm_inf(x)` return the same values as `float`.
`x` is an [array argument](overview.md#array-arguments) of any length, empty included; a NaN or
infinite entry raises `ValueError`, and an overflow `diana.FloatOverflowError`.

```python
>>> import diana
>>> x = [3.0, -4.0, 12.0]
>>> diana.norm_1(x), diana.norm_2(x), diana.norm_inf(x)
(19.0, 13.0, 12.0)
>>> diana.norm_2([1e-200, 1e-200])  # the naive sum of squares underflows to 0
1.414213562373095e-200
>>> diana.norm_2([])
0.0
>>> diana.norm_1([1.7976931348623157e308, 1.7976931348623157e308])
Traceback (most recent call last):
  ...
diana._diana.FloatOverflowError: the norm overflows
>>> diana.norm_inf([1.0, float("nan")])
Traceback (most recent call last):
  ...
ValueError: x has a non-finite entry
```

A NumPy `float64` array is read in place:

```python
>>> import numpy as np
>>> diana.norm_2(np.linspace(-1.0, 1.0, 101))
5.860034129593443
```

## Guarantees

Proved in Lean and Rocq: the three functions are norms (definite, absolutely homogeneous, with
the triangle inequality), `‖x‖∞ ≤ ‖x‖₂ ≤ ‖x‖₁ ≤ n·‖x‖∞`, and the scaled formula of the Euclidean
norm is exact in real arithmetic. Proved in Rocq with Flocq: the maximum norm is exact; the
1-norm is within `γ(n−1)·‖x‖₁` and the Euclidean norm within `γ(n+5)·‖x‖₂ + 2⁻¹⁰⁷⁵` of the exact
value, `γ(k) = k·u/(1 − k·u)`, `u = 2⁻⁵³`; neither overflows unless the norm times `1 + γ` exceeds
`DBL_MAX`; and the Euclidean norm is at least the largest `|x[i]|`. Proved of the C code: VST shows
that each function computes exactly that binary64 value and returns each status exactly when the
model says so, and Frama-C that it is memory-safe and free of undefined behaviour, with the
maximum norm's value proved by Frama-C too. The square root is the compiler builtin
`__builtin_sqrt`, as in the Cholesky factorization (see the
[trust statement](../verification/trust.md)). Theorems: `spec/norm.md`; status: the
[verification report](../verification/report.md).

## Technical notes

[API-037](../../note/api/API-037.md) evaluation order and exits,
[API-038](../../note/api/API-038.md) the Python functions,
[PROOF-013](../../note/proof/PROOF-013.md) what is proved, with the exact bounds,
[WP-014](../../note/wp/WP-014.md) why the WP assertions round with `\round_double`,
[FP-006](../../note/fp/FP-006.md) the square-root helper and its trust.
