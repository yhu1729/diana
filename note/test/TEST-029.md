---
id: TEST-029
title: Newton exact root and stagnation cases
kind: fact
path:
  - test/c/test_newton.c
  - test/python/test_newton.py
  - src/newton_step.c
related: [TEST-027, TEST-028, TEST-031]
---
An exact `f(x) = 0` ends the iteration with `dx = 0`, and with `tol = 0` a step that leaves `x`
unchanged ends it too; these cases pin both stops.

- `x - 1/2` from 0: the first step lands exactly on 0.5 (`dx = -0.5`, `DIANA_CONTINUE`) and the
  second sees `f = 0`, so the run takes two steps and ends with `x = 0.5`, `dx = 0`.
- `fx = 0` is tested before the derivative is used, so `step(0, 0)` from `x = 3` is `DIANA_OK`
  with `dx = 0` and `iter == 1` rather than singular. A NaN or infinite `dfx` is still rejected
  first, since both arguments must be finite.
- Stagnation with `tol = 0` from `x = 1`, `dfx = 1`: a correction of `1e-300` does not change `x`
  (stop, `dx = 1e-300`), nor does one that underflows to 0 (`fx = DBL_TRUE_MIN`, `dfx = 4`: stop,
  `dx = 0`). `fx = -2^-53` gives `dx = -2^-53`, and `1 + 2^-53` is a tie that rounds to even,
  back to 1: stop with `dx = -2^-53`. `fx = +2^-53` moves `x` to `1 - 2^-53`, since the spacing
  below 1 is `2^-53`, and the iteration continues.
- NEWTON-B3 is the general statement: a step that leaves `x` unchanged has `|dx| <= ulp(x)/2`.
