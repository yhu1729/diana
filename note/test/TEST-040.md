---
id: TEST-040
title: LU solve Python tests against a binary64 reference and the B bounds
kind: fact
path:
  - test/python/test_lu_solve.py
related: [API-035, PROOF-012, TEST-039]
---
`test/python/test_lu_solve.py` covers the containers of API-020 for `lu` and `b`, any iterable
of `int` for `piv`, the C pins of TEST-039, the extension's checks of API-035, and four numerical
properties. `test_pivot_snapshot` passes a `piv` list whose first item's `__index__` empties it:
the call solves with the original rows (the tuple copy of API-035, step 5) and reads no freed
item.

- `reference(lu, piv, b)` is the kernel in Python floats, which round each operation to binary64
  without contraction, returning both solves `(y, x)`: the kernel matches it bit for bit on the
  factors of seeded random matrices (`n` up to 31, right-hand sides scaled by 1, `1e-300` and
  `2⁹⁰⁰`) and on 500 Hypothesis systems of finite entries with random `piv[k] < n` (`n` up to 6),
  where the reference's `"singular"` must be `SingularError` and its `"overflow"` a
  `FloatOverflowError`.
- The classes are separate: `test_overflow` expects exactly `FloatOverflowError` ("the solution
  overflows"), and `test_nonfinite_lu` and `test_nonfinite_rhs` exactly `ValueError`
  ("non-finite").
- For `n = 1` to 24 the solve equals `forward_substitution` with the unit lower factor on `P·b`
  followed by `transpose_substitution` with the transposed upper factor, bit for bit.
- LU-SOLVE-B1 to B4 (PROOF-012) hold in exact `Fraction` arithmetic for `n = 1, 2, 5, 10, 20`,
  matrices and right-hand sides scaled by 1, `2⁻¹⁰⁰⁰` and `2¹⁰⁰⁰`, with `y` from the reference
  and `x` from the kernel.
- `diana.lu_solve(*diana.lu(a), b)` agrees with `numpy.linalg.solve(A, b)` to `rtol 1e-9` for
  `n = 3, 10, 40`.
