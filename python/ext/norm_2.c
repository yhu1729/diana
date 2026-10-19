#include "module.h"

PyObject *diana_py_norm_2(PyObject *Py_UNUSED(self), PyObject *args,
                          PyObject *kwds) {
  return diana_py_norm(args, kwds, "O:norm_2", diana_norm_2);
}
