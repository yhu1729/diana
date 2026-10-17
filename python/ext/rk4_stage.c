#include <stddef.h>

#include "module.h"

PyObject *diana_py_rk4_stage(PyObject *Py_UNUSED(self), PyObject *args,
                             PyObject *kwds) {
  static char *kwlist[] = {"y", "k", "h", "stage", "out", NULL};
  PyObject *y;
  PyObject *k;
  PyObject *out;
  double h;
  int stage;
  Py_buffer vy;
  Py_buffer vk;
  Py_buffer vo;
  PyObject *ret = NULL;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "OOdiO:rk4_stage", kwlist, &y,
                                   &k, &h, &stage, &out)) {
    return NULL;
  }
  if (stage < 2 || stage > 4) {
    PyErr_SetString(PyExc_ValueError, "stage must be 2, 3 or 4");
    return NULL;
  }
  if (diana_py_get_samples(y, &vy, "y", 0, 1,
                           "y must have at least one sample") < 0) {
    return NULL;
  }
  if (diana_py_get_samples(k, &vk, "k", 0, 1,
                           "k must have at least one sample") < 0) {
    goto release_y;
  }
  if (diana_py_get_samples(out, &vo, "out", 1, 1,
                           "out must have at least one sample") < 0) {
    goto release_k;
  }
  if (vk.shape[0] != vy.shape[0]) {
    PyErr_SetString(PyExc_ValueError, "y and k must have the same length");
    goto cleanup;
  }
  if (vo.shape[0] != vy.shape[0]) {
    PyErr_SetString(PyExc_ValueError, "out must have the same length as y");
    goto cleanup;
  }
  if (diana_py_overlap(&vo, &vy) || diana_py_overlap(&vo, &vk)) {
    PyErr_SetString(PyExc_ValueError, "out must not overlap y or k");
    goto cleanup;
  }
  st = diana_rk4_stage((const double *)vy.buf, (const double *)vk.buf,
                       (size_t)vy.shape[0], h, stage, (double *)vo.buf);
  if (st != DIANA_OK) {
    diana_py_raise(st, "RK4 stage result is not finite");
    goto cleanup;
  }
  ret = Py_None;
  Py_INCREF(ret);

cleanup:
  PyBuffer_Release(&vo);
release_k:
  PyBuffer_Release(&vk);
release_y:
  PyBuffer_Release(&vy);
  return ret;
}
