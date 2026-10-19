# Cholesky factorization

The Cholesky factorization writes a symmetric positive definite matrix as `A = L·Lᵀ` with `L`
lower triangular and positive on the diagonal. It is the standard first step for solving
`A·x = b` with such a matrix, and it fails, at a pivot that is not positive, exactly when the
matrix is not positive definite. Shared conventions are in the [API overview](overview.md).

## C

`#include <diana/cholesky.h>`.

- `diana_cholesky(a, n, l)` factors the `n×n` matrix stored column-major in `a`
  (`a[i + j·n] = A[i, j]`, `n·n` doubles) and writes `L` to `l` in the same layout, with the
  strict upper triangle set to `+0`. Only the entries on or below the diagonal of `a` are read.
  It returns `DIANA_OK`; `DIANA_ERR_ARG` without writing `l` for a `NULL` pointer, `n = 0`, an
  `n` whose `n·n` does not fit in `size_t`, or a NaN or infinite entry on or below the diagonal;
  or `DIANA_ERR_SINGULAR` when a pivot is not positive, the matrix not being positive definite
  to working precision. After `DIANA_ERR_SINGULAR` the contents of `l` are unspecified: the
  factorization cannot check before it writes, since each column needs the columns before it
  (the LU factorization and the triangular solves have the same limit on their overflow and
  singular paths).

Column `j` is computed from columns `0` to `j − 1`: the pivot `A[j,j] − L[j,0]² − … − L[j,j−1]²`
subtracts the rounded products in that order, `L[j,j]` is its correctly rounded square root, and
each `L[i,j]` below it is `(A[i,j] − L[i,0]·L[j,0] − …)` divided by `L[j,j]`. `a` is only read
and must not overlap `l`. Factoring a matrix built from an integer `L`, whose factorization is
exact, and an indefinite one:

```c
#include <stdio.h>

#include <diana/cholesky.h>

#define N 3

int main(void) {
  /* A = [[4, 2, -2], [2, 10, 5], [-2, 5, 21]], stored column by column */
  const double a[N * N] = {4.0, 2.0, -2.0, 2.0, 10.0, 5.0, -2.0, 5.0, 21.0};
  const double b[4] = {1.0, 2.0, 2.0, 1.0};
  double l[N * N];
  diana_status st = diana_cholesky(a, N, l);
  if (st != DIANA_OK) {
    fprintf(stderr, "cholesky: %s\n", diana_status_str(st));
    return 1;
  }
  for (size_t i = 0; i < N; ++i) {
    for (size_t j = 0; j < N; ++j) {
      printf(" %5.2f", l[i + j * N]);
    }
    printf("\n");
  }
  st = diana_cholesky(b, 2, l);
  printf("indefinite: %s\n", diana_status_str(st));
  return 0;
}
```

```text
  2.00  0.00  0.00
  1.00  3.00  0.00
 -1.00  2.00  4.00
indefinite: zero derivative or pivot
```

## Python

`diana.cholesky(a)` returns `L` as a new `array.array("d")` in the same column-major layout.
`a` is an [array argument](overview.md#array-arguments) whose length `n·n` is a square; a length
that is not, or a NaN or infinite entry on or below the diagonal, raises `ValueError`, and a
matrix that is not positive definite raises `diana.SingularError`. With NumPy, pass
`A.ravel(order="F")` (for a symmetric `A` the same as `A.ravel()`) and reshape the result with
`order="F"`:

```python
>>> import diana
>>> list(diana.cholesky([4.0, 2.0, -2.0, 2.0, 10.0, 5.0, -2.0, 5.0, 21.0]))
[2.0, 1.0, -1.0, 0.0, 3.0, 2.0, 0.0, 0.0, 4.0]
>>> import numpy as np
>>> A = np.array([[4.0, 2.0], [2.0, 5.0]])
>>> L = np.asarray(diana.cholesky(A.ravel(order="F"))).reshape(2, 2, order="F")
>>> L
array([[2., 0.],
       [1., 2.]])
>>> bool(np.array_equal(L @ L.T, A))
True
>>> diana.cholesky([1.0, 2.0, 2.0, 1.0])
Traceback (most recent call last):
  ...
diana._diana.SingularError: matrix is not positive definite: a pivot is not positive
```

## Guarantees

Proved in Lean and Rocq: in exact arithmetic the pivots are all positive exactly when the
symmetric matrix is positive definite, and then `L·Lᵀ = A`. Proved in Rocq with Flocq: when the
binary64 factorization succeeds, every entry of `L` is finite, and `L·Lᵀ = A + ΔA` with
`|ΔA[i,j]| <= γ(j+2)·Σ_k |L[i,k]·L[j,k]|` plus an underflow term of order `n·2⁻¹⁰⁷⁵`, where
`γ(k) = k·u/(1 − k·u)` and `u = 2⁻⁵³`: the factor is exact for a matrix within a relative
`(n + 1)·u` of `A`, measured against `|L|·|Lᵀ|`. Proved of the C code: VST shows that it computes
exactly that binary64 factor and returns each status exactly when the model says so, and Frama-C
that it is memory-safe and free of undefined behaviour. The square root is the compiler builtin
`__builtin_sqrt`, whose CompCert semantics the VST proof assumes (see the
[trust statement](../verification/trust.md)). Theorems: `spec/cholesky.md`; status: the
[verification report](../verification/report.md).

## Technical notes

[API-028](../../note/api/API-028.md) evaluation order and exits,
[API-029](../../note/api/API-029.md) the Python function,
[PROOF-009](../../note/proof/PROOF-009.md) what is proved, with the exact bounds,
[FP-006](../../note/fp/FP-006.md) the square-root helper and its trust,
[WP-011](../../note/wp/WP-011.md) how WP proves the nonlinear index bounds.
