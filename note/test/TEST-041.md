---
id: TEST-041
title: Bisection and Newton status field and the rejection of a finished state
kind: fact
path:
  - test/c/test_bisection.c
  - test/c/test_newton.c
  - src/bisection_step.c
  - src/newton_step.c
related: [API-007, API-010, TEST-009, TEST-031]
---
`test_status_field` in `test/c/test_bisection.c` and in `test/c/test_newton.c` checks the
`status` field after each call, and that `step` rejects, with `DIANA_ERR_ARG` and the state equal
to its copy (`same_state`, which compares `status` too), a state whose `status` is not
`DIANA_CONTINUE`.

- Bisection on `[0, 2]` with `fa = -1`, `fb = 1`, `tol = 0`: with `max_iter = 2`, `init` and a
  first `step(-1)` leave `DIANA_CONTINUE`, the second `step(-1)` writes `DIANA_ERR_MAXITER`, and a
  further `step(1)` is rejected; with `max_iter = 10`, `step(0)` writes `DIANA_OK` and the next
  `step(1)` is rejected the same way. `init` writes `DIANA_OK` for a zero `fa` and for
  `tol = 4 >= b - a`.
- Newton from 2 with `tol = 0` and `max_iter = 1`: `DIANA_ERR_SINGULAR` (`fx = 1`, `dfx = 0`) and
  `DIANA_ERR_OVERFLOW` (`fx = DBL_MAX`, `dfx = 0.5`) keep `DIANA_CONTINUE`, `step(2, 4)` reaches
  the limit and writes `DIANA_ERR_MAXITER`, and `step(1, 1)` is rejected; with `max_iter = 10`,
  `step(2, 4)` keeps `DIANA_CONTINUE`, `step(0, 1)` writes `DIANA_OK`, and the next is rejected.
- A zero-initialized struct, whose `status` 0 reads as `DIANA_OK`, is rejected by both `step`s
  and left all zero.
