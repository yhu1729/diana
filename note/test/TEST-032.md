---
id: TEST-032
title: Newton callback wrapper cases
kind: fact
path:
  - test/c/test_newton.c
  - src/newton.c
related: [TEST-030, TEST-031]
---
`diana_newton` calls the callback once per step, resetting `*dfx` to 0 before each call, and
writes `*root` only when the iteration ends with `DIANA_OK` or `DIANA_ERR_MAXITER`.

- One evaluation per step: `x^2 - 2` from 2 with `tol = 1e-12` makes six calls and reports
  `iter == 6`; the cube root of 10 takes five.
- `DIANA_ERR_MAXITER` with `max_iter = 3` still writes the estimate `1.4142156862745099` and
  `iter == 3`.
- `*root` stays untouched (and `*iter` is 0) when `f` or `root` is NULL, when `init` rejects the
  arguments (NaN `x0`, negative `tol`, `max_iter = 0`; no callback call), when the derivative is
  zero (`DIANA_ERR_SINGULAR`), and when the callback never writes `*dfx`, which the reset turns
  into a zero derivative (`DIANA_ERR_SINGULAR`).
- A non-finite value on the second call returns `DIANA_ERR_ARG` with `*root` untouched and
  `*iter == 1`, the completed steps.
- `iter` may be NULL.
