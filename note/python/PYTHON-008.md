---
id: PYTHON-008
title: State objects are unusable until initialization succeeds
kind: fact
path:
  - python/ext/bisection_new.c
  - python/ext/bisection_init.c
  - python/ext/bisection_step.c
  - python/ext/bisection_result.c
  - python/ext/newton_new.c
  - python/ext/newton_init.c
  - python/ext/newton_step.c
  - python/ext/newton_result.c
related: [PYTHON-001, API-022]
---
`Bisection.__new__` and `Newton.__new__` (`diana_py_<kernel>_new`) set the read-only `status` to
`ERR_ARG`; `step` and `result` raise `RuntimeError` (`… state is not initialized`) while it is
`ERR_ARG`, and `step` also raises `RuntimeError` on a finished state (status not `CONTINUE`).

- `__init__` calls the C `init` directly on the object's state. On an error status it raises
  (`diana_py_raise`) and leaves `status` alone; the C `init` writes nothing on error, so a failed
  reinitialization keeps the previous valid state.
- `Bisection(...)` accepts `DIANA_OK` (already converged) or `DIANA_CONTINUE`; `Newton(...)`
  accepts only `DIANA_CONTINUE`.
- A `step` that raises (`ValueError`, `SingularError`, `FloatOverflowError`) leaves `status`
  unchanged, so the caller may retry with another value; only a returned status is stored.
- `max_iter` goes through `diana_py_convert_uint` (`OverflowError` above `UINT_MAX`); the
  defaults are 2100 for `Bisection` and 100 for `Newton`, which takes `tol` without a default.
