---
id: TEST-047
title: Axpy Python tests against binary64 evaluation and the B2 bound
kind: fact
path:
  - test/python/test_axpy.py
related: [TEST-046, API-040, PROOF-014]
---
`test/python/test_axpy.py` checks the binding and, through it, the C kernel.

- Containers: `x` as a list, tuple, iterator, `Fraction`s, `array.array`, NumPy array,
  memoryview, read-only memoryview and ctypes array, against `y` as an `array.array`, NumPy
  array, memoryview and ctypes array, all giving the exact `{2, 1, −3.75}`; `y` is updated in
  place (the same object, a NumPy slice included) and `x` is unchanged; keywords and an integer
  or `numpy.float64` `a`.
- `test_matches_binary64` (Hypothesis, 500 examples, any doubles, up to 40 pairs): the kernel
  must match `v + a * u` in Python floats bit for bit, raise `FloatOverflowError` exactly when a
  component is not finite with finite inputs, and `ValueError` (not the overflow subclass)
  exactly when `a` or an entry is not finite, leaving `y` unchanged on both.
- `test_rounding_error_bound` checks AXPY-B2 per component in exact `Fraction` arithmetic on
  four vectors (normal, a product that underflows, large, subnormal).
- Pins of TEST-046 in Python: the inverse update, the signed zeros of `a = ±0`, the FMA case,
  the underflow tie, the cancelling `DBL_MAX − DBL_MAX`.
- Errors: lengths that differ, overlapping NumPy slices (and the non-overlapping halves of one
  array succeed), read-only `y` (`bytes`, a read-only memoryview, a NumPy array with
  `writeable = False`), wrong dtype (`TypeError`), layout and alignment (`ValueError`), a list
  or tuple as `y` and a string `a` (`TypeError`), and the extension function with a list.
