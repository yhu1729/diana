---
id: PYTHON-001
title: Extension source layout in python/ext
kind: fact
path:
  - python/ext/*.c
  - python/ext/*.h
related: [PYTHON-003, PYTHON-007, STYLE-002, API-020, API-022]
---
`python/ext/` holds the C sources of the extension module `diana._diana`, one function per file,
each named after its function without `diana_py_` (STYLE-002); all are listed in
`Python_add_library(_diana ...)` of `CMakeLists.txt`.

- `module.c`: the `PyModuleDef` (`m_size = -1`, PYTHON-003), the `version` method, and
  `PyInit__diana`, which calls each `diana_py_<kernel>_exec(m)` in turn and drops the module if
  one fails.
- `module.h`: shared declarations, the exception pointers `diana_py_bracket_error` and
  `diana_py_singular_error`, and the `static inline` byte-range overlap test `diana_py_overlap`.
- `status_exec.c`: registers `status_str`, the status constants `OK` to `ERR_SINGULAR`, and
  creates `BracketError` and `SingularError` (both `ValueError` subclasses).
- `raise.c` (`diana_py_raise`): `DIANA_ERR_ARG` raises `ValueError`, `DIANA_ERR_BRACKET`
  `BracketError`, `DIANA_ERR_SINGULAR` `SingularError`, any other status `RuntimeError`; the
  message is the caller's or `diana_status_str`.
- `convert_uint.c`: the `O&` converter for `unsigned int` (`__index__`, `OverflowError` above
  `UINT_MAX`); `get_array.c`: the buffer check `diana_py_get_array` (API-020); `version.c`,
  `status_str.c`: the two module functions.
- Per kernel, `<kernel>_exec.c` holds the static method, member and type tables and registers
  them. The state types have `<kernel>_new.c`, `_init.c`, `_step.c`, `_result.c` and the object
  struct in `bisection_object.h` / `newton_object.h`; the array functions are `trapezoidal.c`,
  `simpson.c`, `euler_step.c`, `rk4_stage.c`, `rk4_step.c` and `cholesky.c`.

The extension is ordinary tested code, not verified; it may use libm (`newton_step.c` calls
`isfinite`) and is compiled with the strict flags (BUILD-001).
