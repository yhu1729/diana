---
id: TEST-009
title: A rejected bisection call keeps the state, and Python relies on it
kind: fact
path:
  - test/c/test_bisection.c
  - test/python/test_bisection.py
  - python/ext/bisection_init.c
  - python/ext/bisection_step.c
related: [API-003, TEST-007, TEST-031]
---
A rejected `diana_bisection_init` or `diana_bisection_step` leaves every field of the state
unchanged. `test_error_keeps_state` in `test/c/test_bisection.c` compares all eight fields after a
bracket error and an argument error from `init` on a running state, and after a NaN `fx` to
`step`.

- The Python binding depends on it: `Bisection.__init__` calls `diana_bisection_init` directly on
  the object's state and `step` calls `diana_bisection_step`; on an error both raise without
  restoring anything. `test_failed_reinitialization_preserves_state` checks every attribute and
  `result()` after a `TypeError`, `ValueError` and `BracketError` from `__init__`, then finishes
  the iteration.
- An object never initialized successfully has status `ERR_ARG`; `step` and `result` raise
  `RuntimeError` (`test_uninitialized_state`, `test_failed_initialization`), and `step` after
  `OK` raises `RuntimeError` too.
- The wrapper `diana_bisection` returns an `init` error or a non-finite `f` at a midpoint with
  `*root` untouched and `*iter` set to the completed steps (0 in the tests); a NULL `f` or `root`
  is `DIANA_ERR_ARG`, and `iter` may be NULL. On `DIANA_ERR_MAXITER` it still writes the
  estimate: after 5 steps on `[0, 2]` the C test checks it within `2/64` of `sqrt(2)`; Python's
  `MaxIterError` carries it as `estimate` (checked within `2/32`) with `iter == 5`.
