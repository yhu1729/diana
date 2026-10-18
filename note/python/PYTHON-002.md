---
id: PYTHON-002
title: Pure-Python package layout and private driver modules
kind: fact
path:
  - python/src/diana/*.py
  - python/src/diana/_diana.pyi
  - python/src/diana/py.typed
related: [PYTHON-001, PYTHON-004, PYTHON-006, API-022]
---
`python/src/diana/` is the pure-Python package. `__init__.py` re-exports every public name from
private modules, so `diana.<name>` is the whole API.

- `_error.py` defines only `MaxIterError` (a `RuntimeError` with `estimate`, `uncertainty` and
  `iter`); it re-exports `BracketError`, `SingularError` and `FloatOverflowError`, which the
  extension creates.
- `_convert.py` defines `real(x, name)`: `TypeError` unless the type has `__float__` or
  `__index__`, then `float(x)`, so a string is rejected as the C `d` converter rejects it. The
  `_bisection.py`, `_euler.py` and `_rk4.py` drivers apply it to scalars they use in Python
  (calling `f`, computing `t0 + k*h`); `_newton.py` passes its scalars straight to the C type.
- One private driver module per kernel: `_bisection.py` (`bisection`), `_newton.py` (`newton`),
  `_trapezoidal.py`, `_simpson.py`, `_euler.py` (`euler_step`, `euler`), `_rk4.py` (`rk4_stage`,
  `rk4_step`, `rk4`), `_cholesky.py` (`cholesky`), `_substitution.py` (`forward_substitution`,
  `transpose_substitution`), `_lu.py` (`lu`), `_lu_solve.py` (`lu_solve`). The single-call array
  functions pass a buffer through
  and copy any other iterable into `array.array("d")`; `euler` and `rk4` copy `y0` element by
  element.
- `__init__.py` also takes `Bisection`, `Newton` and the status constants from `_diana`, aliases
  `version` and `status_str`, and sets `__version__ = version()`.
- `_diana.pyi` is the type stub of the extension and `py.typed` marks the package as typed.

Driver modules are private so that no submodule name equals a public function: importing a
submodule `diana.bisection` would bind the module object to the attribute `diana.bisection` and
shadow the function.
