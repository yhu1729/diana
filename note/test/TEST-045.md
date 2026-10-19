---
id: TEST-045
title: Norm Python tests against a binary64 model and the B bounds
kind: fact
path:
  - test/python/test_norm.py
related: [TEST-044, API-038, PROOF-013]
---
`test/python/test_norm.py` checks the binding and, through it, the C kernels.

- Containers: lists, tuples, iterators, ints, `Fraction`s, `array.array`, NumPy arrays,
  memoryviews and ctypes arrays give the same results; a NumPy slice is read in place; empty
  inputs of every kind give `+0`.
- `test_matches_sequential_binary64` (Hypothesis, 500 examples, any doubles, up to 40 entries):
  `sequential_1` and `sequential_2` evaluate the C order with Python floats, which are binary64
  rounded to nearest-even, and the kernels must match them bit for bit, raise
  `FloatOverflowError` exactly when the model is not finite, and `ValueError` (not the overflow
  subclass) exactly when an entry is not finite; `norm_inf` must equal `max(abs(v))`.
- `test_sign_and_scale`: negating every entry changes no bit; scaling by `2⁶⁴` scales the result
  exactly when every entry and the result stay within `2^±900`.
- `test_rounding_error_bound` checks NORM-B2 and B4 in exact `Fraction` arithmetic on six
  vectors (normal, subnormal, near-overflow, wide range, tiny, the order pin); B4 is checked on
  squares, `(r − η)² ≤ (1 + γ)²·S` and `(1 − γ)²·S ≤ (r + η)²`, with `S` the exact sum of squares;
  also `r ≥ ‖x‖∞` (B6) and the exact maximum norm (B1).
- Errors: wrong dtype (`TypeError`), layout and alignment (`ValueError`), non-buffer arguments
  of the extension functions.
