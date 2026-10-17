#include <stddef.h>

#include "module.h"

PyObject *diana_py_euler_step(PyObject *Py_UNUSED(self), PyObject *args,
                              PyObject *kwds) {
  static char *kwlist[] = {"y", "f", "h", "out", NULL};
  PyObject *y;
  PyObject *f;
  PyObject *out;
  double h;
  Py_buffer vy;
  Py_buffer vf;
  Py_buffer vo;
  PyObject *ret = NULL;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "OOdO:euler_step", kwlist, &y,
                                   &f, &h, &out)) {
    return NULL;
  }
  if (diana_py_get_samples(y, &vy, "y", 0, 1,
                           "y must have at least one sample") < 0) {
    return NULL;
  }
  if (diana_py_get_samples(f, &vf, "f", 0, 1,
                           "f must have at least one sample") < 0) {
    goto release_y;
  }
  if (diana_py_get_samples(out, &vo, "out", 1, 1,
                           "out must have at least one sample") < 0) {
    goto release_f;
  }
  if (vf.shape[0] != vy.shape[0]) {
    PyErr_SetString(PyExc_ValueError, "y and f must have the same length");
    goto cleanup;
  }
  if (vo.shape[0] != vy.shape[0]) {
    PyErr_SetString(PyExc_ValueError, "out must have the same length as y");
    goto cleanup;
  }
  if (diana_py_overlap(&vo, &vy) || diana_py_overlap(&vo, &vf)) {
    PyErr_SetString(PyExc_ValueError, "out must not overlap y or f");
    goto cleanup;
  }
  st = diana_euler_step((const double *)vy.buf, (const double *)vf.buf,
                        (size_t)vy.shape[0], h, (double *)vo.buf);
  if (st != DIANA_OK) {
    diana_py_raise(st, "Euler step result is not finite");
    goto cleanup;
  }
  ret = Py_None;
  Py_INCREF(ret);

cleanup:
  PyBuffer_Release(&vo);
release_f:
  PyBuffer_Release(&vf);
release_y:
  PyBuffer_Release(&vy);
  return ret;
}
