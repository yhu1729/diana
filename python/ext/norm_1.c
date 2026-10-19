#include "module.h"

PyObject *diana_py_norm_1(PyObject *Py_UNUSED(self), PyObject *args,
                          PyObject *kwds) {
  return diana_py_norm(args, kwds, "O:norm_1", diana_norm_1);
}
