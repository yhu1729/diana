#include <stddef.h>

#include "module.h"

static PyObject *mod_simpson(PyObject *Py_UNUSED(self), PyObject *args,
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
  if (diana_py_get_samples(y, &view, "y", 0, 3,
                           "y must have at least three samples") < 0) {
    return NULL;
  }
  if (view.shape[0] % 2 == 0) {
    PyErr_SetString(PyExc_ValueError, "y must have an odd number of samples");
    goto cleanup;
  }
  st = diana_simpson((const double *)view.buf, (size_t)view.shape[0], h, &r);
  if (st != DIANA_OK) {
    diana_py_raise(st, "Simpson result is not finite");
    goto cleanup;
  }
  out = PyFloat_FromDouble(r);

cleanup:
  PyBuffer_Release(&view);
  return out;
}

static PyMethodDef simpson_method[] = {
    {"simpson", (PyCFunction)(void (*)(void))mod_simpson,
     METH_VARARGS | METH_KEYWORDS,
     "simpson(y, h) -> float\n\nComposite Simpson rule "
     "h/3 * (y[0] + 4*y[1] + 2*y[2] + ... + 4*y[n-2] + y[n-1]) over a "
     "one-dimensional, C-contiguous, aligned buffer y of an odd number of "
     "native float64, read in place."},
    {NULL, NULL, 0, NULL}};

int diana_py_simpson_exec(PyObject *m) {
  return PyModule_AddFunctions(m, simpson_method);
}
