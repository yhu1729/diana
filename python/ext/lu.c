#include <stddef.h>

#include "module.h"

PyObject *diana_py_lu(PyObject *Py_UNUSED(self), PyObject *args,
                      PyObject *kwds) {
  static char *kwlist[] = {"a", "out", NULL};
  PyObject *a;
  PyObject *out;
  Py_buffer va;
  Py_buffer vo;
  Py_ssize_t n;
  Py_ssize_t k;
  size_t *piv = NULL;
  PyObject *list;
  PyObject *index;
  PyObject *ret = NULL;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "OO:lu", kwlist, &a, &out)) {
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
  piv = PyMem_New(size_t, (size_t)n);
  if (piv == NULL) {
    PyErr_NoMemory();
    goto cleanup;
  }
  st = diana_lu((const double *)va.buf, (size_t)n, (double *)vo.buf, piv);
  if (st != DIANA_OK) {
    diana_py_raise(st, st == DIANA_ERR_SINGULAR
                           ? "matrix is singular: a pivot column is zero"
                           : "a has a non-finite entry, or an update "
                             "overflows");
    goto cleanup;
  }
  list = PyList_New(n);
  if (list == NULL) {
    goto cleanup;
  }
  for (k = 0; k < n; ++k) {
    index = PyLong_FromSize_t(piv[k]);
    if (index == NULL) {
      Py_DECREF(list);
      goto cleanup;
    }
    PyList_SET_ITEM(list, k, index);
  }
  ret = list;

cleanup:
  PyMem_Free(piv);
  PyBuffer_Release(&vo);
release_a:
  PyBuffer_Release(&va);
  return ret;
}
