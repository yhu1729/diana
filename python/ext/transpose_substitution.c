#include "module.h"

PyObject *diana_py_transpose_substitution(PyObject *Py_UNUSED(self),
                                          PyObject *args, PyObject *kwds) {
  return diana_py_substitution(args, kwds, "OOO:transpose_substitution",
                               diana_transpose_substitution);
}
