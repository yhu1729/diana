#include <stddef.h>

#include "module.h"

PyObject *diana_py_simpson(PyObject *Py_UNUSED(self), PyObject *args,
                           PyObject *kwds) {
  static char *kwlist[] = {"y", "h", NULL};
  PyObject *y;
  double h;
  double r = 0.0;
  Py_buffer view;
  PyObject *out = NULL;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "Od:simpson", kwlist, &y, &h)) {
    return NULL;
  }
  if (diana_py_get_array(y, &view, "y", 0, 3,
                         "y must have at least three samples") < 0) {
    return NULL;
  }
  if (view.shape[0] % 2 == 0) {
    PyErr_SetString(PyExc_ValueError, "y must have an odd number of samples");
    goto cleanup;
  }
  st = diana_simpson((const double *)view.buf, (size_t)view.shape[0], h, &r);
  if (st != DIANA_OK) {
    diana_py_raise(st, st == DIANA_ERR_OVERFLOW
                           ? "Simpson result overflows"
                           : "Simpson input is not finite: a sample or h");
    goto cleanup;
  }
  out = PyFloat_FromDouble(r);

cleanup:
  PyBuffer_Release(&view);
  return out;
}
