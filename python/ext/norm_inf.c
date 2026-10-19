#include "module.h"

PyObject *diana_py_norm_inf(PyObject *Py_UNUSED(self), PyObject *args,
                            PyObject *kwds) {
  return diana_py_norm(args, kwds, "O:norm_inf", diana_norm_inf);
}
