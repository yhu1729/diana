# Python binding

The binding has two parts: a hand-written CPython extension `diana._diana` in C, and a small
pure-Python package `diana` that wraps it. What the binding exposes is described in the
[API overview](../api/overview.md).

- **Extension, `python/ext/`.** It follows the library's one-function-per-file rule:
  `module.c` defines the module, each kernel registers its functions and types in
  `<kernel>_exec.c`, and each method or function has its own file (`bisection_step.c`). Array
  arguments are read in place through the buffer protocol, so the extension needs no NumPy. The
  sources live outside the package directory, so the wheel does not ship them.
- **Package, `python/src/diana/`.** One private driver module per kernel (`_bisection.py`,
  `_euler.py`, …) holds the convenience functions that loop over a Python callable; `__init__.py`
  re-exports everything. `_diana.pyi` types the extension, so the package is fully typed.

The callable loops run in Python and are not part of the verified code; the extension calls the
same verified C kernels as the C API. The extension supports one interpreter per process.

To add a kernel to the binding, follow an existing one such as `simpson`: its C function file,
its `_exec.c`, its declarations in `module.h`, the call in `module.c`, the file list in
`CMakeLists.txt`, the driver module, the stub and the re-export (note PYTHON-007 lists them).

## Technical notes

[PYTHON-001](../../note/python/PYTHON-001.md) extension layout,
[PYTHON-002](../../note/python/PYTHON-002.md) package layout,
[PYTHON-003](../../note/python/PYTHON-003.md) single-phase initialization,
[PYTHON-004](../../note/python/PYTHON-004.md) output buffers,
[PYTHON-007](../../note/python/PYTHON-007.md) adding a kernel,
[API-020](../../note/api/API-020.md) array arguments,
[API-023](../../note/api/API-023.md) state objects.
