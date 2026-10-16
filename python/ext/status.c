#include <limits.h>

#include "module.h"

PyObject *diana_py_bracket_error;
PyObject *diana_py_singular_error;

void diana_py_raise(diana_status st, const char *msg) {
  PyObject *type;

  switch (st) {
  case DIANA_ERR_ARG:
    type = PyExc_ValueError;
    break;
  case DIANA_ERR_BRACKET:
    type = diana_py_bracket_error;
    break;
  case DIANA_ERR_SINGULAR:
    type = diana_py_singular_error;
    break;
  default:
    type = PyExc_RuntimeError;
    break;
  }
  PyErr_SetString(type, msg != NULL ? msg : diana_status_str(st));
}

static PyObject *mod_status_str(PyObject *Py_UNUSED(self), PyObject *arg) {
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

static PyMethodDef status_method[] = {{"status_str", mod_status_str, METH_O,
                                       "Human-readable name of a status code."},
                                      {NULL, NULL, 0, NULL}};

int diana_py_status_exec(PyObject *m) {
  if (PyModule_AddFunctions(m, status_method) < 0) {
    return -1;
  }
  diana_py_bracket_error = PyErr_NewExceptionWithDoc(
      "diana._diana.BracketError", "f(a) and f(b) have the same strict sign.",
      PyExc_ValueError, NULL);
  if (diana_py_bracket_error == NULL ||
      PyModule_AddObjectRef(m, "BracketError", diana_py_bracket_error) < 0) {
    return -1;
  }
  diana_py_singular_error = PyErr_NewExceptionWithDoc(
      "diana._diana.SingularError",
      "The derivative (Newton) or a pivot is zero, so the step is undefined.",
      PyExc_ValueError, NULL);
  if (diana_py_singular_error == NULL ||
      PyModule_AddObjectRef(m, "SingularError", diana_py_singular_error) < 0) {
    return -1;
  }
  if (PyModule_AddIntConstant(m, "OK", DIANA_OK) < 0 ||
      PyModule_AddIntConstant(m, "CONTINUE", DIANA_CONTINUE) < 0 ||
      PyModule_AddIntConstant(m, "ERR_ARG", DIANA_ERR_ARG) < 0 ||
      PyModule_AddIntConstant(m, "ERR_BRACKET", DIANA_ERR_BRACKET) < 0 ||
      PyModule_AddIntConstant(m, "ERR_MAXITER", DIANA_ERR_MAXITER) < 0 ||
      PyModule_AddIntConstant(m, "ERR_SINGULAR", DIANA_ERR_SINGULAR) < 0) {
    return -1;
  }
  return 0;
}
