# LU solve

Solving `A·x = b` with a general square matrix takes two steps: the
[LU factorization](lu.md) `P·A = L·U`, then this solve with its factors. The solve applies the
row interchanges to `b`, giving `P·b`, solves `L·y = P·b` with the unit lower-triangular `L` and
then `U·x = y` with the upper-triangular `U`. The factors can be reused for any number of
right-hand sides. Shared conventions are in the [API overview](overview.md).

## C

`#include <diana/lu_solve.h>`.

- `diana_lu_solve(lu, piv, n, b, x)` takes the packed factor `lu` (`n·n` doubles, column-major:
  `L` strictly below the diagonal, its diagonal of ones not stored, `U` on and above it) and the
  pivot rows `piv` (`n` values of type `size_t`) exactly as `diana_lu` writes them, and the
  right-hand side `b` (`n` doubles), and writes the solution to `x` (`n` doubles).
- It returns `DIANA_OK`; `DIANA_ERR_ARG` without writing `x` for a `NULL` pointer, `n = 0`, an
  `n` whose `n·n` does not fit in `size_t`, a NaN or infinite entry of `lu` or `b`, or a pivot row
  `piv[k] >= n`; `DIANA_ERR_SINGULAR` without writing `x` when a diagonal entry of `U` is zero,
  which `diana_lu` never returns; or `DIANA_ERR_OVERFLOW` when an entry of `y` or `x` overflows,
  after which the contents of `x` are unspecified: the solve works in place in `x`.

The kernel copies `b` to `x`, interchanges `x[k]` and `x[piv[k]]` for `k = 0, 1, …, n−1`, then
computes `y[i] = x[i] − L[i,0]·y[0] − … − L[i,i−1]·y[i−1]` (no division: the diagonal of `L` is
one) and `x[i] = (y[i] − U[i,n−1]·x[n−1] − … − U[i,i+1]·x[i+1]) / U[i,i]` from the bottom up, each
product rounded and subtracted in the order its unknown was computed. `x` must not overlap `lu`,
`piv` or `b`. Factoring a matrix and solving with two right-hand sides:

```c
#include <stdio.h>

#include <diana/lu.h>
#include <diana/lu_solve.h>

#define N 3

int main(void) {
  /* A = [[2, 1, 1], [4, -6, 0], [-2, 7, 2]], stored column by column */
  const double a[N * N] = {2.0, 4.0, -2.0, 1.0, -6.0, 7.0, 1.0, 0.0, 2.0};
  const double b[2][N] = {{3.0, 16.0, -10.0}, {1.0, 0.0, 0.0}};
  double lu[N * N];
  size_t piv[N];
  double x[N];
  diana_status st = diana_lu(a, N, lu, piv);
  if (st != DIANA_OK) {
    fprintf(stderr, "lu: %s\n", diana_status_str(st));
    return 1;
  }
  for (size_t r = 0; r < 2; ++r) {
    st = diana_lu_solve(lu, piv, N, b[r], x);
    if (st != DIANA_OK) {
      fprintf(stderr, "lu_solve: %s\n", diana_status_str(st));
      return 1;
    }
    printf("x = (%g, %g, %g)\n", x[0], x[1], x[2]);
  }
  return 0;
}
```

```text
x = (1, -2, 3)
x = (0.75, 0.5, -1)
```

## Python

`diana.lu_solve(lu, piv, b)` returns the solution as a new `array.array("d")`; `lu` and `b` are
[array arguments](overview.md#array-arguments) and `piv` any iterable of `int`, so
`diana.lu_solve(*diana.lu(a), b)` solves `A·x = b`. A length of `lu` other than `n·n` or of `piv`
other than `n`, a NaN or infinite entry, or a pivot row not below `n` raises `ValueError`; an
overflow `diana.FloatOverflowError`, a negative pivot row the built-in `OverflowError`, and a zero
on the diagonal of `U` `diana.SingularError`:

```python
>>> import diana
>>> a = [2.0, 4.0, -2.0, 1.0, -6.0, 7.0, 1.0, 0.0, 2.0]
>>> lu, piv = diana.lu(a)
>>> list(diana.lu_solve(lu, piv, [3.0, 16.0, -10.0]))
[1.0, -2.0, 3.0]
>>> import numpy as np
>>> A = np.array(a).reshape(3, 3, order="F")
>>> x = diana.lu_solve(lu, piv, np.array([1.0, 0.0, 0.0]))
>>> bool(np.allclose(A @ np.asarray(x), [1.0, 0.0, 0.0]))
True
>>> diana.lu_solve(lu, [1, 3, 2], [3.0, 16.0, -10.0])
Traceback (most recent call last):
  ...
ValueError: lu or b has a non-finite entry, or a pivot row is not below n
```

## Guarantees

Proved in Lean and Rocq: in exact arithmetic the interchanges form a permutation for any pivot
rows below `n`, the solve gives `L·U·x = P·b` whenever `U` has no zero on its diagonal, and with
the factors of a nonsingular `A` it solves `A·x = b`. Proved in Rocq with Flocq: when the binary64
solve succeeds, each row of each triangular solve has a backward error of at most
`γ(m)·Σ|terms|` plus an underflow term, `m` the number of products of the row,
`γ(k) = k·u/(1 − k·u)` and `u = 2⁻⁵³`; together, `|P·b − L·U·x|` is at most the forward-solve bound
plus `|L|` times the back-solve bounds, and with the factors of `diana_lu`, `|P·b − P·A·x|` adds
the factorization's bound applied to `|x|`: Higham's `(A + ΔA)·x = b` with
`|ΔA| ≲ 3γ(n)·|L|·|U|`, in componentwise residual form. Proved of the C code: VST shows that it
computes exactly that binary64 solution and returns each status exactly when the model says so,
and Frama-C that it is memory-safe and free of undefined behaviour. As for the factorization, the
bound is relative to `|L|·|U|`, and no forward error bound is proved: the error in `x` also grows
with the condition number of `A`. Theorems: `spec/lu_solve.md`; status: the
[verification report](../verification/report.md).

## Technical notes

[API-034](../../note/api/API-034.md) evaluation order and exits,
[API-035](../../note/api/API-035.md) the Python function,
[PROOF-012](../../note/proof/PROOF-012.md) what is proved, with the exact bounds,
[WP-011](../../note/wp/WP-011.md) how WP proves the nonlinear index bounds,
[TEST-039](../../note/test/TEST-039.md) the C test values.
