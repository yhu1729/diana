# LU factorization

The LU factorization with partial pivoting writes a square matrix as `P·A = L·U`, with `L` unit
lower triangular, `U` upper triangular and `P` a row permutation. It is the standard first step for
solving `A·x = b` with a general matrix, the [LU solve](lu_solve.md) being the second: each step
takes as pivot the entry of largest magnitude in its column, which keeps every multiplier at most 1
in magnitude. In exact arithmetic it fails, at a pivot column that is entirely zero, exactly when
the matrix is singular. Shared conventions are in the [API overview](overview.md).

## C

`#include <diana/lu.h>`.

- `diana_lu(a, n, lu, piv)` factors the `n×n` matrix stored column-major in `a`
  (`a[i + j·n] = A[i, j]`, `n·n` doubles) and writes the packed factor to `lu` in the same
  layout: `L` strictly below the diagonal (its diagonal of ones is not stored) and `U` on and
  above it. `piv[k]` (`n` values of type `size_t`) is the row interchanged with row `k` at step
  `k`, with `k <= piv[k] < n`; applying the interchanges in order to the rows of `A` gives `P·A`,
  as with LAPACK's `getrf` counting from 0.
- It returns `DIANA_OK`; `DIANA_ERR_ARG` without writing `lu` or `piv` for a `NULL` pointer,
  `n = 0`, an `n` whose `n·n` does not fit in `size_t`, or a NaN or infinite entry of `a`;
  `DIANA_ERR_SINGULAR` when every candidate pivot of a column is zero; or `DIANA_ERR_ARG` when an
  update overflows. After the last two the contents of `lu` and `piv` are unspecified: each step
  needs the steps before it, so the kernel writes as it goes.

Step `k` scans column `k` from the diagonal down for the first entry of largest magnitude,
interchanges its row with row `k` across all columns, divides the entries below the pivot by it,
and subtracts `L[i,k]·U[k,j]`, the product rounded first, from every entry below and right of the
pivot. `a` is only read and must not overlap `lu` or `piv`. Factoring a matrix whose first
column has two entries of the largest magnitude, and a singular one:

```c
#include <stdio.h>

#include <diana/lu.h>

#define N 3

int main(void) {
  /* A = [[2, 2, 1], [-3, 1, 0], [3, -9, 6]], stored column by column */
  const double a[N * N] = {2.0, -3.0, 3.0, 2.0, 1.0, -9.0, 1.0, 0.0, 6.0};
  const double s[4] = {1.0, 2.0, 2.0, 4.0};
  double lu[N * N];
  size_t piv[N];
  diana_status st = diana_lu(a, N, lu, piv);
  if (st != DIANA_OK) {
    fprintf(stderr, "lu: %s\n", diana_status_str(st));
    return 1;
  }
  for (size_t i = 0; i < N; ++i) {
    for (size_t j = 0; j < N; ++j) {
      printf(" %6.3f", lu[i + j * N]);
    }
    printf("   piv[%zu] = %zu\n", i, piv[i]);
  }
  st = diana_lu(s, 2, lu, piv);
  printf("singular: %s\n", diana_status_str(st));
  return 0;
}
```

```text
 -3.000  1.000  0.000   piv[0] = 1
 -1.000 -8.000  6.000   piv[1] = 2
 -0.667 -0.333  3.000   piv[2] = 2
singular: zero derivative or pivot
```

## Python

`diana.lu(a)` returns `(lu, piv)`: the packed factor as a new `array.array("d")` in the same
column-major layout, and the pivot rows as a `list` of `int`. `a` is an
[array argument](overview.md#array-arguments) whose length `n·n` is a square; a length that is
not, a NaN or infinite entry, or an update that overflows raises `ValueError`, and a zero pivot
column raises `diana.SingularError`. With NumPy, pass `A.ravel(order="F")` and reshape the result
with `order="F"`:

```python
>>> import diana
>>> f, piv = diana.lu([2.0, -3.0, 3.0, 2.0, 1.0, -9.0, 1.0, 0.0, 6.0])
>>> piv
[1, 2, 2]
>>> [round(x, 3) for x in f]
[-3.0, -1.0, -0.667, 1.0, -8.0, -0.333, 0.0, 6.0, 3.0]
>>> import numpy as np
>>> A = np.array([[2.0, 2.0, 1.0], [-3.0, 1.0, 0.0], [3.0, -9.0, 6.0]])
>>> F = np.asarray(f).reshape(3, 3, order="F")
>>> L = np.tril(F, -1) + np.eye(3)
>>> U = np.triu(F)
>>> rows = list(range(3))
>>> for k, p in enumerate(piv):
...     rows[k], rows[p] = rows[p], rows[k]
>>> bool(np.allclose(A[rows], L @ U))
True
>>> diana.lu([1.0, 2.0, 2.0, 4.0])
Traceback (most recent call last):
  ...
diana._diana.SingularError: matrix is singular: a pivot column is zero
```

## Guarantees

Proved in Lean and Rocq: in exact arithmetic the factorization succeeds exactly when `A` is
nonsingular, and then `P·A = L·U`, the interchanges form a permutation and every multiplier has
magnitude at most 1. Proved in Rocq with Flocq: when the binary64 factorization succeeds, every
entry is finite, the multipliers are still at most 1 in magnitude, and `P·A + ΔA = L·U` with
`|ΔA[i,j]| <= γ(m+1)·Σ_t |L[i,t]·U[t,j]|`, `m = min(i, j)`, plus an underflow term of order
`n·2⁻¹⁰⁷⁵`, where `γ(k) = k·u/(1 − k·u)` and `u = 2⁻⁵³`: Higham's componentwise bound
`|ΔA| <= γ(n)·|L|·|U|`. Proved of the C code: VST shows that it computes exactly that binary64
factor and those pivot rows and returns each status exactly when the model says so, and Frama-C
that it is memory-safe and free of undefined behaviour. The bound is relative to `|L|·|U|`, which
partial pivoting keeps small for most matrices but not all (the growth factor can reach
`2^(n−1)`). Theorems: `spec/lu.md`; status: the [verification report](../verification/report.md).

## Technical notes

[API-032](../../note/api/API-032.md) evaluation order and exits,
[API-033](../../note/api/API-033.md) the Python function,
[PROOF-011](../../note/proof/PROOF-011.md) what is proved, with the exact bounds,
[WP-011](../../note/wp/WP-011.md) how WP proves the nonlinear index bounds,
[TEST-037](../../note/test/TEST-037.md) the C test values.
