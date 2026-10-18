---
id: TEST-017
title: Euler overflow, non-finite input and the untouched output on error
kind: fact
path:
  - test/c/test_euler.c
  - test/python/test_euler.py
related: [TEST-016, TEST-018, KERNEL-002, API-003]
---
Every rejected Euler case leaves all 100 slots of the output buffer at the sentinel 42, which
shows that the first pass rejects before the second pass writes. `check_reject` takes the expected
status: `DIANA_ERR_OVERFLOW` for an overflow of finite inputs, `DIANA_ERR_ARG` otherwise.

- Overflow with finite inputs, in exactly one operation, `DIANA_ERR_OVERFLOW`: the product
  (`0 + 2 * DBL_MAX` and `0 - 2 * DBL_MAX`) or the sum (`DBL_MAX + DBL_MAX`,
  `-DBL_MAX - DBL_MAX`).
- Non-finite input, `DIANA_ERR_ARG`: NaN or `+inf` in each `y[i]`, NaN or `-inf` in each `f[i]`
  (three components), NaN or `±inf` as `h`; `inf + 1 * (-inf)` and `y + 0 * inf` give NaN.
- Classification (`test_overflow_classify`): `y = f = (DBL_MAX, 1, 1)` with `h = 1` overflows in
  the first component, `DIANA_ERR_OVERFLOW`; NaN in `y[2]` or `-inf` in `f[2]` makes the same call
  `DIANA_ERR_ARG`, since the kernel checks every input, not only those up to the failure.
- Failure position: `(1, 2, DBL_MAX) + 1 * (1, 1, DBL_MAX)` fails in the last component and
  `(DBL_MAX, 1, 1) + 1 * (DBL_MAX, 2, 3)` in the first, both `DIANA_ERR_OVERFLOW`; neither writes
  any slot.
- Argument errors, for the checked and the unchecked step: NULL `y`, `f` or `y_out`, both NULL,
  and `d == 0`; `DIANA_ERR_ARG`, the output stays untouched.
- Python: an overflow raises `diana.FloatOverflowError` ("result overflows"); a non-finite input,
  also one after an overflowing component, raises a plain `ValueError` ("input is not finite",
  never a `FloatOverflowError`). `test_step_failure_leaves_out` checks through
  `diana._diana.euler_step` that a caller's `out` keeps its values after either failure, with the
  first component overflowing and the last `1` or NaN.
