---
id: TEST-027
title: Newton on x^2 - 2 from 2 stops after six steps within the quadratic bound
kind: fact
path:
  - test/c/test_newton.c
  - test/python/test_newton.py
  - src/newton_step.c
related: [TEST-028, TEST-029]
---
`diana_newton_step` computes `dx = fx / dfx` and `x - dx`, and stops when `x` does not change or
`|dx| <= tol`. On `x^2 - 2` from `x0 = 2` with `tol = 1e-12` both tests require six steps,
`DIANA_OK`, a result within `1e-12` of `sqrt(2)`, and `0 < |dx| <= 1e-12`.

- Quadratic bound: `f'' = 2` and `f' = 2x >= 2 sqrt(2)` on `[sqrt(2), 2]`, so NEWTON-A1 bounds
  each error by `K e^2` with `K = 2 / (4 sqrt(2)) = 0.354` while the iterate stays above the root.
  The tests check `err <= 0.36 * prev^2` for the first five steps.
- The iterates, which the tests do not assert one by one: `1.5`, `1.4166666666666667`,
  `1.4142156862745099`, `1.4142135623746899`, `1.4142135623730951` (the correctly rounded
  `sqrt(2)`), then `1.414213562373095`. At the rounded root the computed `f` is `2^-51`, not 0, so
  step 6 moves one ulp down with `dx = 1.57e-16 <= 1e-12` and stops; the result is the lower
  neighbour of `sqrt(2)`.
- The state after `init` is `x = 2`, `dx = 0`, `tol = 1e-12`, `iter = 0`, `max_iter = 100`
  (the Python default), and `result` returns `(x, dx)`.
- The C wrapper test reproduces it with `diana_newton` (six steps, six callback calls);
  `diana.newton` is checked only for a root within `1e-12`.
