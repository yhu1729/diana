#include <stddef.h>

#include "module.h"

static PyObject *mod_trapezoidal(PyObject *Py_UNUSED(self), PyObject *args,
                                 PyObject *kwds) {
  static char *kwlist[] = {"y", "h", NULL};
  PyObject *y;
  double h;
  double r = 0.0;
  Py_buffer view;
  PyObject *out = NULL;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "Od:trapezoidal", kwlist, &y,
                                   &h)) {
    return NULL;
  }
  if (diana_py_get_samples(y, &view, 2, "y must have at least two samples") <
      0) {
    return NULL;
  }
  st =
      diana_trapezoidal((const double *)view.buf, (size_t)view.shape[0], h, &r);
  if (st != DIANA_OK) {
    diana_py_raise(st, "trapezoidal result is not finite");
    goto cleanup;
  }
  out = PyFloat_FromDouble(r);

cleanup:
  PyBuffer_Release(&view);
  return out;
}

static PyMethodDef trapezoidal_method[] = {
    {"trapezoidal", (PyCFunction)(void (*)(void))mod_trapezoidal,
     METH_VARARGS | METH_KEYWORDS,
     "trapezoidal(y, h) -> float\n\nComposite trapezoidal rule "
     "h * (y[0]/2 + y[1] + ... + y[n-2] + y[n-1]/2) over a one-dimensional, "
     "C-contiguous, aligned buffer y of native float64, read in place."},
    {NULL, NULL, 0, NULL}};

int diana_py_trapezoidal_exec(PyObject *m) {
  return PyModule_AddFunctions(m, trapezoidal_method);
}
