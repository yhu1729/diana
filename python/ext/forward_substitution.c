#include "module.h"

PyObject *diana_py_forward_substitution(PyObject *Py_UNUSED(self),
                                        PyObject *args, PyObject *kwds) {
  return diana_py_substitution(args, kwds, "OOO:forward_substitution",
                               diana_forward_substitution);
}
