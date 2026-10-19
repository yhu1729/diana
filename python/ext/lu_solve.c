#include <stddef.h>

#include "module.h"

PyObject *diana_py_lu_solve(PyObject *Py_UNUSED(self), PyObject *args,
                            PyObject *kwds) {
  static char *kwlist[] = {"lu", "piv", "b", "out", NULL};
  PyObject *lu;
  PyObject *piv;
  PyObject *b;
  PyObject *out;
  Py_buffer vl;
  Py_buffer vb;
  Py_buffer vo;
  Py_ssize_t n;
  Py_ssize_t k;
  PyObject *iter;
  PyObject *seq = NULL;
  PyObject *index;
  size_t *rows = NULL;
  PyObject *ret = NULL;
  diana_status st;
  const char *msg;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "OOOO:lu_solve", kwlist, &lu,
                                   &piv, &b, &out)) {
    return NULL;
  }
  if (diana_py_get_array(lu, &vl, "lu", 0, 1,
                         "lu must have at least one sample") < 0) {
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
                    "lu must have n*n samples, n the length of b");
    goto cleanup;
  }
  if (vo.shape[0] != n) {
    PyErr_SetString(PyExc_ValueError, "out must have the same length as b");
    goto cleanup;
  }
  if (diana_py_overlap(&vo, &vl) || diana_py_overlap(&vo, &vb)) {
    PyErr_SetString(PyExc_ValueError, "out must not overlap lu or b");
    goto cleanup;
  }
  /* The test PyObject_GetIter applies, so a TypeError raised by piv's own
     __iter__ is kept, with its context. */
  if (Py_TYPE(piv)->tp_iter == NULL && !PySequence_Check(piv)) {
    PyErr_SetString(PyExc_TypeError, "piv must be an iterable of int");
    goto cleanup;
  }
  iter = PyObject_GetIter(piv);
  if (iter == NULL) {
    goto cleanup;
  }
  seq = PySequence_Tuple(iter);
  Py_DECREF(iter);
  if (seq == NULL) {
    goto cleanup;
  }
  if (PyTuple_GET_SIZE(seq) != n) {
    PyErr_SetString(PyExc_ValueError, "piv must have the same length as b");
    goto cleanup;
  }
  rows = PyMem_New(size_t, (size_t)n);
  if (rows == NULL) {
    PyErr_NoMemory();
    goto cleanup;
  }
  for (k = 0; k < n; ++k) {
    index = PyNumber_Index(PyTuple_GET_ITEM(seq, k));
    if (index == NULL) {
      goto cleanup;
    }
    rows[k] = PyLong_AsSize_t(index);
    Py_DECREF(index);
    if (rows[k] == (size_t)-1 && PyErr_Occurred()) {
      goto cleanup;
    }
  }
  st = diana_lu_solve((const double *)vl.buf, rows, (size_t)n,
                      (const double *)vb.buf, (double *)vo.buf);
  if (st != DIANA_OK) {
    if (st == DIANA_ERR_SINGULAR) {
      msg = "matrix is singular: a diagonal entry of U is zero";
    } else if (st == DIANA_ERR_OVERFLOW) {
      msg = "the solution overflows";
    } else {
      msg = "lu or b has a non-finite entry, or a pivot row is not below n";
    }
    diana_py_raise(st, msg);
    goto cleanup;
  }
  ret = Py_None;
  Py_INCREF(ret);

cleanup:
  PyMem_Free(rows);
  Py_XDECREF(seq);
  PyBuffer_Release(&vo);
release_b:
  PyBuffer_Release(&vb);
release_l:
  PyBuffer_Release(&vl);
  return ret;
}
