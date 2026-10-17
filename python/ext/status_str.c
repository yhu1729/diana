#include <limits.h>

#include "module.h"

PyObject *diana_py_status_str(PyObject *Py_UNUSED(self), PyObject *arg) {
  long v = PyLong_AsLong(arg);
  if (v == -1 && PyErr_Occurred()) {
    return NULL;
  }
  if (v < INT_MIN || v > INT_MAX) {
    PyErr_SetString(PyExc_OverflowError, "status code does not fit in a C int");
    return NULL;
  }
  return PyUnicode_FromString(diana_status_str((diana_status)v));
}
