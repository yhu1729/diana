---
id: TEST-017
title: Euler overflow, non-finite input and the untouched output on error
kind: fact
path:
  - test/c/test_euler.c
  - test/python/test_euler.py
related: [TEST-016, TEST-018, KERNEL-002, API-003]
---
Every rejected Euler case returns `DIANA_ERR_ARG` and leaves all 100 slots of the output buffer at
the sentinel 42, which shows that the first pass rejects before the second pass writes.

- Overflow with finite inputs, in exactly one operation: the product (`0 + 2 * DBL_MAX` and
  `0 - 2 * DBL_MAX`) or the sum (`DBL_MAX + DBL_MAX`, `-DBL_MAX - DBL_MAX`).
- Non-finite input: NaN or `+inf` in each `y[i]`, NaN or `-inf` in each `f[i]` (three
  components), NaN or `±inf` as `h`; `inf + 1 * (-inf)` and `y + 0 * inf` give NaN.
- Failure position: `(1, 2, DBL_MAX) + 1 * (1, 1, DBL_MAX)` fails in the last component and
  `(DBL_MAX, 1, 1) + 1 * (DBL_MAX, 2, 3)` in the first; neither writes any slot.
- Argument errors, for the checked and the unchecked step: NULL `y`, `f` or `y_out`, both NULL,
  and `d == 0`; the output stays untouched.
- Python: the same rejections raise `ValueError` ("not finite"), and
  `test_step_failure_leaves_out` checks through `diana._diana.euler_step` that a caller's `out`
  keeps its values after a failure in the last component.
