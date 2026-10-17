---
id: TEST-030
title: Newton double root, step limit, cube root and cos fixed point
kind: fact
path:
  - test/c/test_newton.c
  - test/python/test_newton.py
related: [TEST-027, TEST-032]
---
Four Newton cases pin behaviour beyond simple roots.

- Double root: `x^2` from 1 with `tol = 1e-6` converges linearly. Each step has `dx = x/2`, so `x`
  halves, and `|dx| <= 1e-6` first holds at step 20, where `x = dx = 2^-20` (`DIANA_OK`, C and
  Python).
- Step limit: `max_iter = 3` on `x^2 - 2` from 2 stops with `DIANA_ERR_MAXITER` at the third
  iterate `1.4142156862745099`, which `diana_newton_result`, the wrapper's `*root` and
  `MaxIterError.estimate` report (`0 < uncertainty < 0.003` in Python).
- Cube root: `x^3 - 10` from 2 with `tol = 1e-12` takes five steps (asserted by the C wrapper
  test) to `2.154434690031884`, the correctly rounded `10^(1/3)`; both tests assert that value.
- `cos x - x` from 1 with `tol = 1e-12` (Python only): the root `r` satisfies `cos(r) == r`
  exactly in binary64, which the test asserts. With the platform's `math.cos` the fourth step
  reaches `0.7390851332151607` and the fifth sees `f = 0`.
