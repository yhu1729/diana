#include "module.h"

PyObject *diana_py_back_substitution(PyObject *Py_UNUSED(self), PyObject *args,
                                     PyObject *kwds) {
  return diana_py_substitution(args, kwds, "OOO:back_substitution",
                               diana_back_substitution);
}
