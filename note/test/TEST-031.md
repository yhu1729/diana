---
id: TEST-031
title: Newton singular and argument errors keep the state
kind: fact
path:
  - test/c/test_newton.c
  - test/python/test_newton.py
  - src/newton_step.c
related: [TEST-009, TEST-029, API-002, API-022]
---
Every rejected Newton call leaves the state unchanged: `test_error` in `test/c/test_newton.c`
compares all five fields after each rejection.

- `DIANA_ERR_SINGULAR`: `dfx = 0` or `-0` with a non-zero `fx` (`1` and `-1`). Python raises
  `SingularError` (a `ValueError`, message containing `f'(x) is zero`) and the object keeps
  `x`, `dx`, `iter` and status `CONTINUE`; a later `step(0, dfx)` still returns `OK`.
- `DIANA_ERR_ARG` from `step`: NULL state; NaN or infinite `fx` or `dfx`; a correction that
  overflows (`fx = DBL_MAX`, `dfx = 1/2`, and `fx = 1`, `dfx = DBL_TRUE_MIN`); an iterate that
  overflows (`x = -DBL_MAX`, `fx = DBL_MAX`, `dfx = 1`, so `x - dx = -2 DBL_MAX`). From the same
  `x`, `fx = -DBL_MAX`, `dfx = 2` gives the finite `-DBL_MAX/2` and continues.
- `DIANA_ERR_ARG` from `init`: NULL state, NaN or infinite `x0`, NaN or `-inf` `tol`, negative
  `tol` (`-DBL_TRUE_MIN`), `max_iter = 0`; `tol = -0` is accepted. A rejected reinitialization of
  a running state keeps it.
- `result` with a NULL state is `DIANA_ERR_ARG` and writes nothing; either output pointer may be
  NULL.
- Python maps the step errors to `ValueError` ("must be finite", "step is not finite") through
  `diana.newton`.
