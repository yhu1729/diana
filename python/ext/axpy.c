#include <stddef.h>

#include "module.h"

PyObject *diana_py_axpy(PyObject *Py_UNUSED(self), PyObject *args,
                        PyObject *kwds) {
  static char *kwlist[] = {"a", "x", "y", NULL};
  double a;
  PyObject *x;
  PyObject *y;
  Py_buffer vx;
  Py_buffer vy;
  const double empty_x = 0.0;
  double empty_y = 0.0;
  PyObject *ret = NULL;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "dOO:axpy", kwlist, &a, &x,
                                   &y)) {
    return NULL;
  }
  if (diana_py_get_array(x, &vx, "x", 0, 0, "x must be a vector") < 0) {
    return NULL;
  }
  if (diana_py_get_array(y, &vy, "y", 1, 0, "y must be a vector") < 0) {
    goto release_x;
  }
  if (vy.shape[0] != vx.shape[0]) {
    PyErr_SetString(PyExc_ValueError, "y must have the same length as x");
    goto cleanup;
  }
  if (diana_py_overlap(&vy, &vx)) {
    PyErr_SetString(PyExc_ValueError, "y must not overlap x");
    goto cleanup;
  }
  st = diana_axpy(a, vx.shape[0] == 0 ? &empty_x : (const double *)vx.buf,
                  (size_t)vx.shape[0],
                  vx.shape[0] == 0 ? &empty_y : (double *)vy.buf);
  if (st != DIANA_OK) {
    diana_py_raise(st, st == DIANA_ERR_OVERFLOW
                           ? "axpy result overflows"
                           : "axpy input is not finite: a, x or y");
    goto cleanup;
  }
  ret = Py_None;
  Py_INCREF(ret);

cleanup:
  PyBuffer_Release(&vy);
release_x:
  PyBuffer_Release(&vx);
  return ret;
}
