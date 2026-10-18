---
id: TEST-036
title: Substitution Python tests against a binary64 reference and the B bounds
kind: fact
path:
  - test/python/test_substitution.py
related: [API-031, PROOF-010, TEST-035]
---
`test/python/test_substitution.py` covers the containers of API-020 for both arguments, the
column-major NumPy layout, the C pins of TEST-035, the extension's checks of API-031, and
numerical properties.

- `forward_reference` and `back_reference` are the kernels, their checks included, in Python
  floats (each operation rounded to binary64, no contraction): the kernels match them bit for bit
  on seeded random systems (`n` up to 31, `b` scaled by 1, `1e-300`, `2⁹⁰⁰`) and on 500
  Hypothesis systems of finite entries (`n` up to 6) per kernel, where `"singular"` must raise
  `SingularError`, `"overflow"` a `FloatOverflowError` and success give finite entries.
- The classes are separate: an overflow raises `FloatOverflowError` ("the solution overflows"),
  and a NaN or infinity in `lower` or `b` raises exactly `ValueError` ("non-finite"), not a
  subclass.
- Back substitution equals forward substitution on the mirrored system bit for bit (`n` up to 24).
- B1 and B3 (PROOF-010) hold in exact `Fraction` arithmetic, and so do B2 and B4: the error
  against the exact rational solution is at most the comparison-matrix solve of the row bounds;
  `n = 2, 5, 10, 20`, `b` scaled by 1, `2⁻¹⁰⁰⁰` and `2¹⁰⁰⁰`.
- `cholesky`, then both solves, agree with `numpy.linalg.solve` to `rtol 1e-12` for
  well-conditioned `n = 3, 10, 40`.
