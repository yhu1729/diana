#include <stddef.h>

#include "module.h"

PyObject *diana_py_cholesky(PyObject *Py_UNUSED(self), PyObject *args,
                            PyObject *kwds) {
  static char *kwlist[] = {"a", "out", NULL};
  PyObject *a;
  PyObject *out;
  Py_buffer va;
  Py_buffer vo;
  Py_ssize_t n;
  PyObject *ret = NULL;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "OO:cholesky", kwlist, &a,
                                   &out)) {
    return NULL;
  }
  if (diana_py_get_array(a, &va, "a", 0, 1, "a must have at least one sample") <
      0) {
    return NULL;
  }
  if (diana_py_get_array(out, &vo, "out", 1, 1,
                         "out must have at least one sample") < 0) {
    goto release_a;
  }
  n = diana_py_square_side(va.shape[0]);
  if (n * n != va.shape[0]) {
    PyErr_SetString(PyExc_ValueError,
                    "a must have n*n samples for some n, a square number");
    goto cleanup;
  }
  if (vo.shape[0] != va.shape[0]) {
    PyErr_SetString(PyExc_ValueError, "out must have the same length as a");
    goto cleanup;
  }
  if (diana_py_overlap(&vo, &va)) {
    PyErr_SetString(PyExc_ValueError, "out must not overlap a");
    goto cleanup;
  }
  st = diana_cholesky((const double *)va.buf, (size_t)n, (double *)vo.buf);
  if (st != DIANA_OK) {
    diana_py_raise(st, st == DIANA_ERR_SINGULAR
                           ? "matrix is not positive definite: a pivot is "
                             "not positive"
                           : "a has a non-finite entry on or below the "
                             "diagonal");
    goto cleanup;
  }
  ret = Py_None;
  Py_INCREF(ret);

cleanup:
  PyBuffer_Release(&vo);
release_a:
  PyBuffer_Release(&va);
  return ret;
}
