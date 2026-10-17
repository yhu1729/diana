---
id: TEST-011
title: Trapezoidal overflow, non-finite, zero-step and underflow cases
kind: fact
path:
  - test/c/test_trapezoidal.c
  - test/python/test_trapezoidal.py
related: [TEST-010, API-003]
---
Every trapezoidal overflow case has finite samples and `h` and overflows in exactly one
operation. The kernel returns `DIANA_ERR_ARG`, and the C test checks that `*result` keeps its
sentinel 42.

- Endpoint sum: `{DBL_MAX, DBL_MAX}` with `h = 1` overflows in `y[0] + y[n-1]` although the exact
  rule `h (y0 + y1) / 2 = DBL_MAX` is representable. With `h = 0` it still fails: `0 * inf` is
  NaN.
- Interior addition: `{DBL_MAX, DBL_MAX, 0}` and its negative with `h = 1` (the halved endpoints
  give `DBL_MAX/2`, then `+ DBL_MAX` overflows).
- Product: `{DBL_MAX, 0}` with `h = 4` or `-4`; with `h = 2` the result is exactly `DBL_MAX`.
- Non-finite input: NaN, `+inf` and `-inf` at each of four positions; `+inf` and `-inf` at both
  ends or in the interior; NaN or `±inf` as `h`, and `h = inf` with all-zero samples.
- Argument errors: NULL `y` (with `n` 3 or 0), NULL `result`, `n` of 0 or 1.
- `h = 0` and `h = -0` give `+0` and `-0` for `{1, 2, 3}`, and `+0` for `{DBL_MAX/2, DBL_MAX/2, 0}`.
- Underflow is a finite result: `{0.5, 0.5}` with `h = DBL_TRUE_MIN` is `0.5 * 2^-1074`, a tie
  that rounds to `+0`, returned with `DIANA_OK`.
