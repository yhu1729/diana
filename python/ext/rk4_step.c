#include <stddef.h>

#include "module.h"

PyObject *diana_py_rk4_step(PyObject *Py_UNUSED(self), PyObject *args,
                            PyObject *kwds) {
  static char *kwlist[] = {"y", "k1", "k2", "k3", "k4", "h", "out", NULL};
  static const char *const name[5] = {"y", "k1", "k2", "k3", "k4"};
  static const char *const empty[5] = {
      "y must have at least one sample", "k1 must have at least one sample",
      "k2 must have at least one sample", "k3 must have at least one sample",
      "k4 must have at least one sample"};
  PyObject *obj[5];
  PyObject *out;
  double h;
  Py_buffer view[5];
  Py_buffer vo;
  int got = 0;
  int have_out = 0;
  int i;
  PyObject *ret = NULL;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "OOOOOdO:rk4_step", kwlist,
                                   &obj[0], &obj[1], &obj[2], &obj[3], &obj[4],
                                   &h, &out)) {
    return NULL;
  }
  for (i = 0; i < 5; ++i) {
    if (diana_py_get_array(obj[i], &view[i], name[i], 0, 1, empty[i]) < 0) {
      goto cleanup;
    }
    ++got;
  }
  if (diana_py_get_array(out, &vo, "out", 1, 1,
                         "out must have at least one sample") < 0) {
    goto cleanup;
  }
  have_out = 1;
  for (i = 1; i < 5; ++i) {
    if (view[i].shape[0] != view[0].shape[0]) {
      PyErr_SetString(PyExc_ValueError,
                      "y, k1, k2, k3 and k4 must have the same length");
      goto cleanup;
    }
  }
  if (vo.shape[0] != view[0].shape[0]) {
    PyErr_SetString(PyExc_ValueError, "out must have the same length as y");
    goto cleanup;
  }
  for (i = 0; i < 5; ++i) {
    if (diana_py_overlap(&vo, &view[i])) {
      PyErr_SetString(PyExc_ValueError, "out must not overlap y or a slope");
      goto cleanup;
    }
  }
  st = diana_rk4_step((const double *)view[0].buf, (const double *)view[1].buf,
                      (const double *)view[2].buf, (const double *)view[3].buf,
                      (const double *)view[4].buf, (size_t)view[0].shape[0], h,
                      (double *)vo.buf);
  if (st != DIANA_OK) {
    diana_py_raise(st, st == DIANA_ERR_OVERFLOW
                           ? "RK4 step result overflows"
                           : "RK4 step input is not finite: y, a slope or h");
    goto cleanup;
  }
  ret = Py_None;
  Py_INCREF(ret);

cleanup:
  if (have_out) {
    PyBuffer_Release(&vo);
  }
  for (i = 0; i < got; ++i) {
    PyBuffer_Release(&view[i]);
  }
  return ret;
}
