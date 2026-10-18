---
id: TEST-038
title: LU Python tests against a binary64 reference and the B3 and B4 bounds
kind: fact
path:
  - test/python/test_lu.py
related: [API-033, PROOF-011, TEST-037]
---
`test/python/test_lu.py` covers the containers of API-020, the column-major NumPy layout and the
reconstruction of `P·A = L·U`, the C pins of TEST-037, the extension's checks of API-033, and
four numerical properties.

- `reference(a, n)` is the kernel in Python floats, which round each operation to binary64
  without contraction: the kernel matches it bit for bit, pivots included, on seeded random
  matrices (`n` up to 31, scaled by 1, `1e-300`, `1e300`) and on 500 Hypothesis matrices of
  finite entries (`n` up to 6), where the reference's `"singular"` must be `SingularError`, its
  `"overflow"` a `ValueError`, and success finite entries, `k <= piv[k] < n` and multipliers of
  magnitude at most 1.
- The B3 and B4 bounds (PROOF-011) hold in exact `Fraction` arithmetic on random matrices with
  `n = 2, 5, 10, 20` scaled by 1, `2⁻¹⁰⁰⁰` and `2¹⁰⁰⁰`.
- Integer `U` with `L` in eighths below 1 and a random row order come back exactly for `n` up to
  20, with `piv` reproducing the order.
- Solving with the factors and `numpy.linalg.solve` agrees with `numpy.linalg.solve(A, b)` to
  `rtol 1e-9` for `n = 3, 10, 40`.
