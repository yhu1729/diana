#include <stddef.h>

#include "module.h"

PyObject *diana_py_substitution(PyObject *args, PyObject *kwds,
                                const char *format, diana_py_solve_fn solve) {
  static char *kwlist[] = {"lower", "b", "out", NULL};
  PyObject *lower;
  PyObject *b;
  PyObject *out;
  Py_buffer vl;
  Py_buffer vb;
  Py_buffer vo;
  Py_ssize_t n;
  PyObject *ret = NULL;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, format, kwlist, &lower, &b,
                                   &out)) {
    return NULL;
  }
  if (diana_py_get_array(lower, &vl, "lower", 0, 1,
                         "lower must have at least one sample") < 0) {
    return NULL;
  }
  if (diana_py_get_array(b, &vb, "b", 0, 1, "b must have at least one sample") <
      0) {
    goto release_l;
  }
  if (diana_py_get_array(out, &vo, "out", 1, 1,
                         "out must have at least one sample") < 0) {
    goto release_b;
  }
  n = vb.shape[0];
  if (n > PY_SSIZE_T_MAX / n || vl.shape[0] != n * n) {
    PyErr_SetString(PyExc_ValueError,
                    "lower must have n*n samples, n the length of b");
    goto cleanup;
  }
  if (vo.shape[0] != n) {
    PyErr_SetString(PyExc_ValueError, "out must have the same length as b");
    goto cleanup;
  }
  if (diana_py_overlap(&vo, &vl) || diana_py_overlap(&vo, &vb)) {
    PyErr_SetString(PyExc_ValueError, "out must not overlap lower or b");
    goto cleanup;
  }
  st = solve((const double *)vl.buf, (size_t)n, (const double *)vb.buf,
             (double *)vo.buf);
  if (st != DIANA_OK) {
    diana_py_raise(st, st == DIANA_ERR_SINGULAR
                           ? "matrix is singular: a diagonal entry is zero"
                       : st == DIANA_ERR_OVERFLOW
                           ? "the solution overflows"
                           : "lower or b has a non-finite entry");
    goto cleanup;
  }
  ret = Py_None;
  Py_INCREF(ret);

cleanup:
  PyBuffer_Release(&vo);
release_b:
  PyBuffer_Release(&vb);
release_l:
  PyBuffer_Release(&vl);
  return ret;
}
