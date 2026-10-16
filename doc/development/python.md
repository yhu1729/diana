# Python binding

How the binding's sources are laid out; what it exposes is in the [API overview](../api/overview.md).

- `python/ext/` holds the C sources of the extension module `diana._diana`: `module.c` (module
  definition, `PyInit__diana`), `module.h` (declarations shared across files), `status.c` (status
  constants, `status_str`, `BracketError`, and `diana_py_raise`, which maps a `diana_status` to a
  Python exception), `convert.c` (argument converters for `PyArg_Parse*` `O&` and the buffer
  check `diana_py_get_samples`), and one file per kernel (`bisection.c`, the `Bisection` type;
  `newton.c`, the `Newton` type; `trapezoidal.c`, `simpson.c` and `euler.c`, the array functions). A new kernel adds `python/ext/<kernel>.c` with a
  `diana_py_<kernel>_exec(PyObject *m)` that registers its types and functions, declares it in
  `module.h`, calls it from `PyInit__diana`, and lists the file in `CMakeLists.txt`.
- `python/src/diana/` is the pure-Python package: `_error.py` (the exceptions defined in Python;
  `BracketError` comes from the extension), `_convert.py` (`real`, the check the drivers apply to
  a scalar argument before `float`: `__float__` or `__index__`, so a string is rejected as the C
  `d` converter rejects it), one private driver module per kernel
  (`_bisection.py`: `diana.bisection`; `_newton.py`: `diana.newton`; `_trapezoidal.py`,
  `_simpson.py`, `_euler.py`), and
  `__init__.py`, which re-exports them and aliases `version`, `status_str` and `__version__`.
  `_diana.pyi` is the type stub of the extension, so the `py.typed` package is typed throughout.
  Driver modules are private so that a module name never shadows the function of the same name.
- The extension sources live outside the package directory so the wheel does not ship them.
- `Bisection.__new__` and `Newton.__new__` allocate an uninitialized state with status `ERR_ARG`.
  `step` and `result` reject it until `__init__` succeeds; a rejected reinitialization preserves a
  prior valid state.
