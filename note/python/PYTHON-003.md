---
id: PYTHON-003
title: Single-phase module initialization and its limits
kind: rationale
path:
  - python/ext/module.c
  - python/ext/status_exec.c
  - python/ext/bisection_exec.c
  - python/ext/newton_exec.c
related: [PYTHON-001, BUILD-001]
---
The extension uses single-phase initialization: `PyModule_Create` on a `PyModuleDef` with
`m_size = -1`, static `PyTypeObject`s for `Bisection` and `Newton`, and the process-global
exception pointers `diana_py_bracket_error`, `diana_py_singular_error` and
`diana_py_float_overflow_error`. Multi-phase
initialization is not used because its slot table (`PyModuleDef_Slot`) stores the exec function
in a `void *` member: converting a function pointer to an object pointer is not ISO C, and gcc
rejects it under `-Wpedantic -Werror` even with an explicit `(void *)` cast (BUILD-001).

Consequences, observed with CPython 3.13 (`.python-version`):
- One interpreter per process. An isolated subinterpreter (`_interpreters.create()`) refuses the
  import with `ImportError: module _diana does not support loading in subinterpreters`; only a
  legacy subinterpreter loads it, and the module's state is process-global, so it is not
  subinterpreter-safe.
- Deleting `diana._diana` from `sys.modules` and importing it again yields a new module object
  holding the same objects (the exception classes, `Bisection` and `Newton`): for
  `m_size = -1` CPython keeps a copy of the first module's dict and does not run `PyInit__diana`
  again. `importlib.reload` returns the same module object.

- No free-threading support: the module never calls `PyUnstable_Module_SetGIL`, so a
  free-threaded build (3.13t, 3.14t) re-enables the GIL on import with a `RuntimeWarning`. That
  is intended: `Bisection.init` and `step` and their `Newton` counterparts write `self->s`
  without a lock, and every array function reads its buffers under the GIL (API-038).
- When an `exec` function after `diana_py_status_exec` fails, `PyInit__diana` clears the three
  exception globals before dropping the module, so a retried import does not leak the first
  classes.

Multi-phase initialization with per-module state would lift the one-interpreter limit; it needs a
way to fill the slot table that `-Wpedantic` accepts on gcc.
