---
id: PYTHON-007
title: Add a kernel to the Python binding
kind: procedure
path:
  - python/ext/module.c
  - python/ext/module.h
  - CMakeLists.txt
  - python/src/diana/__init__.py
  - python/src/diana/_diana.pyi
related: [PYTHON-001, PYTHON-002, PYTHON-004, PYTHON-005, KERNEL-006, API-020]
---
1. One file per extension function, `python/ext/<function>.c` defining `diana_py_<function>`.
   A state type gets `<kernel>_new.c` (sets the C state's `status` to `DIANA_ERR_ARG`, not
   initialized), `_init.c`, `_step.c`, `_result.c` and `<kernel>_object.h` with the object struct
   and their declarations.
   Read arrays with `diana_py_get_array`, map a failed status with `diana_py_raise`.
2. `python/ext/<kernel>_exec.c`: the static method (and member and type) tables with their
   docstrings, and `int diana_py_<kernel>_exec(PyObject *m)`, which registers them
   (`PyModule_AddFunctions`, or `PyType_Ready` and `PyModule_AddObjectRef`).
3. Declare the functions and the exec function in `python/ext/module.h` (or the object header).
4. Call `diana_py_<kernel>_exec(m)` from `PyInit__diana` in `python/ext/module.c`.
5. List every new `.c` file in `Python_add_library(_diana ...)` in `CMakeLists.txt`.
6. Add the signatures to the stub `python/src/diana/_diana.pyi`.
7. Write the private driver `python/src/diana/_<kernel>.py` with docstrings; import its public
   names in `python/src/diana/__init__.py` and add them to `__all__`.
8. Tests in `test/python/test_<kernel>.py`; rebuild and run them (PYTHON-005).
