---
id: TEST-034
title: Cholesky Python tests against a binary64 reference and the B3 bound
kind: fact
path:
  - test/python/test_cholesky.py
related: [API-029, PROOF-009, TEST-033]
---
`test/python/test_cholesky.py` covers the containers of API-020, the column-major NumPy layout,
the C pins of TEST-033, the extension's checks of API-029, and three numerical properties.

- `reference(a, n)` is the kernel in Python floats, which round each operation to binary64
  without contraction, with `math.sqrt` correctly rounded: the kernel matches it bit for bit on
  seeded random SPD matrices `BᵀB + n·I` (`n` up to 31, scaled by 1, `1e-300`, `1e300`) and on
  500 Hypothesis matrices of finite entries (`n` up to 6), where a `None` from the reference must
  be `SingularError` and success must give finite entries.
- The B3 bound (PROOF-009) holds in exact `Fraction` arithmetic on random SPD matrices with
  `n = 2, 5, 10, 20` scaled by 1, `2⁻¹⁰⁰⁰` and `2¹⁰⁰⁰`.
- Agreement with `numpy.linalg.cholesky` (LAPACK, a different operation order) to `rtol 1e-12`
  for well-conditioned `n = 3, 10, 40`.
- Integer factors with `n` up to 12 come back exactly.
