# Forward and transpose substitution

Forward substitution solves `L·x = b` for a lower-triangular `L`, one unknown at a time from the
top; transpose substitution solves `Lᵀ·x = b` from the bottom, back substitution with the transpose
of the same stored factor. The name leaves `back_substitution` free for a solve with an
upper-triangular matrix stored as such. Together they turn the
[Cholesky factorization](cholesky.md) `A = L·Lᵀ` into a solver for `A·x = b`: first `L·y = b`,
then `Lᵀ·x = y`. Shared conventions are in the [API overview](overview.md).

## C

`#include <diana/substitution.h>`.

- `diana_forward_substitution(l, n, b, x)` solves `L·x = b` and
  `diana_transpose_substitution(l, n, b, x)` solves `Lᵀ·x = b`, with `L` stored column-major in `l`
  (`l[i + k·n] = L[i, k]`, `n·n` doubles), `b` and `x` of `n` doubles. Only the entries of `l` on
  or below the diagonal are read, so the output of `diana_cholesky` goes in as it is.
- Both return `DIANA_OK`; `DIANA_ERR_ARG` without writing `x` for a `NULL` pointer, `n = 0`, an
  `n` whose `n·n` does not fit in `size_t`, or a NaN or infinite entry of `b` or on or below the
  diagonal of `l`; `DIANA_ERR_SINGULAR` without writing `x` when a diagonal entry is `±0`; and
  `DIANA_ERR_OVERFLOW` when an entry of the solution overflows. Each entry needs the ones computed
  before it, so that last error is found with `x` partly written, and its contents are then
  unspecified.

Forward substitution computes `x[i] = (b[i] − L[i,0]·x[0] − … − L[i,i−1]·x[i−1]) / L[i,i]` for
`i = 0, …, n − 1`, back substitution `x[i] = (b[i] − L[n−1,i]·x[n−1] − … − L[i+1,i]·x[i+1]) /
L[i,i]` for `i = n − 1, …, 0`: each product is rounded and subtracted in the order its unknown
was computed, then divided. `x` must not overlap `l` or `b`; to keep two vectors, solve forward
from `b` into `y` and back from `y` into `b`:

```c
#include <stdio.h>

#include <diana/cholesky.h>
#include <diana/substitution.h>

#define N 3

int main(void) {
  /* A = L L^T for L = [[2, 0, 0], [1, 3, 0], [-1, 2, 4]], column by column */
  const double a[N * N] = {4.0, 2.0, -2.0, 2.0, 10.0, 5.0, -2.0, 5.0, 21.0};
  double b[N] = {-6.0, -3.0, 51.0}; /* A x = b for x = (1, -2, 3) */
  const double zero_diagonal[4] = {1.0, 2.0, 0.0, 0.0};
  double l[N * N];
  double y[N];
  diana_status st = diana_cholesky(a, N, l);
  if (st == DIANA_OK) {
    st = diana_forward_substitution(l, N, b, y); /* L y = b */
  }
  if (st == DIANA_OK) {
    st = diana_transpose_substitution(l, N, y, b); /* L^T x = y, x in b */
  }
  if (st != DIANA_OK) {
    fprintf(stderr, "solve: %s\n", diana_status_str(st));
    return 1;
  }
  printf("x = %g %g %g\n", b[0], b[1], b[2]);
  st = diana_forward_substitution(zero_diagonal, 2, b, y);
  printf("zero diagonal: %s\n", diana_status_str(st));
  return 0;
}
```

```text
x = 1 -2 3
zero diagonal: zero derivative or pivot
```

## Python

`diana.forward_substitution(lower, b)` and `diana.transpose_substitution(lower, b)` return `x` as a
new `array.array("d")`. `lower` and `b` are [array arguments](overview.md#array-arguments), the
length of `lower` the square of that of `b`; a wrong length or a NaN or infinite entry raises
`ValueError`, an overflowing solution `diana.FloatOverflowError`, and a zero diagonal entry
`diana.SingularError`. The factor from `diana.cholesky` goes in as it is; with NumPy, pass
`L.ravel(order="F")`:

```python
>>> import diana
>>> lo = diana.cholesky([4.0, 2.0, -2.0, 2.0, 10.0, 5.0, -2.0, 5.0, 21.0])
>>> y = diana.forward_substitution(lo, [-6.0, -3.0, 51.0])
>>> list(y)
[-3.0, 0.0, 12.0]
>>> list(diana.transpose_substitution(lo, y))
[1.0, -2.0, 3.0]
>>> import numpy as np
>>> L = np.array([[2.0, 0.0], [1.0, 4.0]])
>>> list(diana.forward_substitution(L.ravel(order="F"), [2.0, 9.0]))
[1.0, 2.0]
>>> diana.transpose_substitution([1.0, 0.0, 0.0, 0.0], [1.0, 1.0])
Traceback (most recent call last):
  ...
diana._diana.SingularError: matrix is singular: a diagonal entry is zero
```

## Guarantees

Proved in Lean and Rocq: with no zero on the diagonal, forward and back substitution compute the
unique solution of `L·x = b` and `Lᵀ·x = b`, an approximate solution whose residuals are bounded
by `ρ` is within `M(L)⁻¹·ρ` of it (`M(L)` the comparison matrix, `|L[i,i]|` on and `−|L[i,k]|` off
the diagonal), and for a symmetric positive definite `A` the two solves with its Cholesky factor
solve `A·x = b`. Proved in Rocq with Flocq: when the binary64 solve succeeds, the computed `x̂`
solves `(L + ΔL)·x̂ = b` with `|ΔL[i,k]| <= γ(n)·|L[i,k]|` row by row, plus an underflow term of
order `n·2⁻¹⁰⁷⁵`, where `γ(k) = k·u/(1 − k·u)` and `u = 2⁻⁵³`, and so `|x − x̂| <=
M(L)⁻¹·(γ(n)·|L|·|x̂| + underflow)`. Proved of the C code: VST shows that it computes exactly that
binary64 solution and returns each status exactly when the model says so, and Frama-C that it is
memory-safe and free of undefined behaviour. Theorems: `spec/substitution.md`; status: the
[verification report](../verification/report.md).

## Technical notes

[API-030](../../note/api/API-030.md) evaluation order and exits,
[API-031](../../note/api/API-031.md) the Python functions,
[PROOF-010](../../note/proof/PROOF-010.md) what is proved, with the exact bounds,
[WP-011](../../note/wp/WP-011.md) how WP proves the nonlinear index bounds,
[VST-008](../../note/vst/VST-008.md) a VST tactic quirk the proofs work around.
