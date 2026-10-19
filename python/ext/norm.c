#include <stddef.h>

#include "module.h"

PyObject *diana_py_norm(PyObject *args, PyObject *kwds, const char *format,
                        diana_py_norm_fn norm) {
  static char *kwlist[] = {"x", NULL};
  PyObject *x;
  Py_buffer view;
  const double empty = 0.0;
  double r = 0.0;
  PyObject *out = NULL;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, format, kwlist, &x)) {
    return NULL;
  }
  if (diana_py_get_array(x, &view, "x", 0, 0, "x must be a vector") < 0) {
    return NULL;
  }
  st = norm(view.shape[0] == 0 ? &empty : (const double *)view.buf,
            (size_t)view.shape[0], &r);
  if (st != DIANA_OK) {
    diana_py_raise(st, st == DIANA_ERR_OVERFLOW ? "the norm overflows"
                                                : "x has a non-finite entry");
    goto cleanup;
  }
  out = PyFloat_FromDouble(r);

cleanup:
  PyBuffer_Release(&view);
  return out;
}
