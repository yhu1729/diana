#include "module.h"

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
