#include <stddef.h>
#include <stdint.h>

#include "module.h"

static int is_native_double(const char *format) {
  if (*format == '@' || *format == '=' ||
      *format == (PY_LITTLE_ENDIAN ? '<' : '>')) {
    ++format;
  }
  return format[0] == 'd' && format[1] == '\0';
}

static PyObject *mod_trapezoidal(PyObject *Py_UNUSED(self), PyObject *args,
                                 PyObject *kwds) {
  static char *kwlist[] = {"y", "h", NULL};
  PyObject *y;
  double h;
  double r = 0.0;
  Py_buffer view;
  PyObject *out = NULL;
  const char *format;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "Od:trapezoidal", kwlist, &y,
                                   &h)) {
    return NULL;
  }
  if (PyObject_GetBuffer(y, &view, PyBUF_RECORDS_RO) < 0) {
    return NULL;
  }
  format = view.format != NULL ? view.format : "B";
  if (!is_native_double(format) ||
      view.itemsize != (Py_ssize_t)sizeof(double)) {
    PyErr_Format(PyExc_TypeError,
                 "y must be a buffer of native float64 (format 'd'), not "
                 "format '%s'",
                 format);
    goto cleanup;
  }
  if (view.ndim != 1) {
    PyErr_Format(PyExc_ValueError, "y must be one-dimensional, not %d-D",
                 view.ndim);
    goto cleanup;
  }
  if (view.shape[0] < 2) {
    PyErr_SetString(PyExc_ValueError, "y must have at least two samples");
    goto cleanup;
  }
  if (!PyBuffer_IsContiguous(&view, 'C')) {
    PyErr_SetString(PyExc_ValueError, "y must be C-contiguous");
    goto cleanup;
  }
  if ((uintptr_t)view.buf % _Alignof(double) != 0u) {
    PyErr_SetString(PyExc_ValueError, "y is not aligned for float64");
    goto cleanup;
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
