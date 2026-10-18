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
`Bisection.__new__` and `Newton.__new__` (`diana_py_<kernel>_new`) set the C state's `status`
field, the read-only attribute `status`, to `ERR_ARG`, a value no C `init` or `step` writes;
`step` and `result` raise `RuntimeError` (`… state is not initialized`) while it is `ERR_ARG`, and
`step` also raises `RuntimeError` on a finished state (status not `CONTINUE`) before calling C.

- `__init__` calls the C `init` directly on the object's state. On an error status it raises
  (`diana_py_raise`); the C `init` writes nothing on error, `status` included, so a failed
  reinitialization keeps the previous valid state. On success the C `init` has written `status`.
- `Bisection(...)` accepts `DIANA_OK` (already converged) or `DIANA_CONTINUE`; `Newton(...)`
  accepts only `DIANA_CONTINUE`.
- A `step` that raises (`ValueError`, `SingularError`, `FloatOverflowError`) leaves `status`
  unchanged, since the C `step` writes nothing on those errors, so the caller may retry with
  another value; a returned status is the one the C `step` wrote. The extension stores no status
  of its own.
- `max_iter` goes through `diana_py_convert_uint` (`OverflowError` above `UINT_MAX`); the
  defaults are 2100 for `Bisection` and 100 for `Newton`, which takes `tol` without a default.
