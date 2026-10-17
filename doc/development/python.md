# Python binding

How the binding's sources are laid out; what it exposes is in the [API overview](../api/overview.md).

- `python/ext/` holds the C sources of the extension module `diana._diana`, one function per file
  named after it without `diana_py_`: `module.c` (module definition, `PyInit__diana`), `module.h`
  (declarations shared across files and the `static inline` buffer overlap test
  `diana_py_overlap`), `version.c` and `status_str.c` (the module functions `version` and
  `status_str`), `status_exec.c` (status constants, `BracketError`, `SingularError`), `raise.c`
  (`diana_py_raise`, which maps a `diana_status` to a Python exception), `convert_uint.c` (the
  `PyArg_Parse*` `O&` converter for `unsigned int`) and `get_array.c` (the buffer check
  `diana_py_get_array`). Each kernel has `<kernel>_exec.c`, `diana_py_<kernel>_exec(PyObject *m)`
  with the method, member and type tables it registers, and one file per method or function: the
  `Bisection` type in `bisection_new.c`, `bisection_init.c`, `bisection_step.c` and
  `bisection_result.c` with its object struct in `bisection_object.h`, likewise `Newton` with
  `newton_object.h`, and the array functions in `trapezoidal.c`, `simpson.c`, `euler_step.c`,
  `rk4_stage.c` and `rk4_step.c`. A new kernel adds its function files and `<kernel>_exec.c`,
  declares them in `module.h` (or its object header), calls the exec function from
  `PyInit__diana`, and lists the files in `CMakeLists.txt`.
- `python/src/diana/` is the pure-Python package: `_error.py` (the exceptions defined in Python;
  `BracketError` comes from the extension), `_convert.py` (`real`, the check the drivers apply to
  a scalar argument before `float`: `__float__` or `__index__`, so a string is rejected as the C
  `d` converter rejects it), one private driver module per kernel
  (`_bisection.py`: `diana.bisection`; `_newton.py`: `diana.newton`; `_trapezoidal.py`,
  `_simpson.py`, `_euler.py`, `_rk4.py`), and
  `__init__.py`, which re-exports them and aliases `version`, `status_str` and `__version__`.
  `_diana.pyi` is the type stub of the extension, so the `py.typed` package is typed throughout.
  Driver modules are private so that a module name never shadows the function of the same name.
- The extension sources live outside the package directory so the wheel does not ship them.
- The extension uses single-phase initialization (`m_size = -1`), static type objects and
  module-level exception pointers, so it supports one interpreter per process: it is not
  subinterpreter-safe, and re-importing it after removing it from `sys.modules` creates new
  `BracketError` and `SingularError` objects and leaks the old ones. Multi-phase initialization
  with module state would lift this and is not planned before 1.0.
- `Bisection.__new__` and `Newton.__new__` allocate an uninitialized state with status `ERR_ARG`.
  `step` and `result` reject it until `__init__` succeeds; a rejected reinitialization preserves a
  prior valid state.
