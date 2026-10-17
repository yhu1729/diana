---
id: TEST-016
title: Euler exact steps, the FMA pin, signed zero and underflow
kind: fact
path:
  - test/c/test_euler.c
  - test/python/test_euler.py
  - src/euler_step.c
related: [TEST-017, TEST-018, FP-004]
---
`diana_euler_step` writes `y[i] + h * f[i]` with the product and the sum rounded separately. The
C tests use inputs whose expected bits follow exactly, and every successful case also runs
`diana_euler_step_unchecked` (TEST-018).

- Exact: `y = {1, -2, 1/2}`, `f = {3, 4, -8}`, `h = 1/4` give `{1.75, -1, -1.5}` (also with
  `d = 1`); 100 components `y = i - 50`, `f = 3 - i`, `h = 1/2` give `i/2 - 48.5`.
- No contraction: `y = -1`, `f = 1 - 2^-52`, `h = 1 + 2^-52`. The product `1 - 2^-104` rounds to
  1, so the result is `+0`; a fused multiply-add would give `-2^-104`, so a build that contracts
  `y + h * f` into an FMA fails this case (`-ffp-contract=off` forbids it). Python
  `test_step_no_contraction` repeats it.
- `h = 0` keeps each `y[i]` with its sign: `-0 + 0 * (-3) = -0 + -0 = -0` and
  `0 + 0 * (-1) = +0 + -0 = +0`.
- Underflow is not an error: `0 + 0.5 * DBL_TRUE_MIN` is a tie that rounds to `+0`.
  `DBL_MAX + 1 * 1` rounds back to `DBL_MAX`, a finite result.
- Every expected value is compared with `==` and with `signbit`, so `+0` and `-0` differ.
