#include "bisection_object.h"

PyObject *diana_py_bisection_result(BisectionObject *self,
                                    PyObject *Py_UNUSED(ignored)) {
  double root, width;
  if (self->s.status == DIANA_ERR_ARG) {
    PyErr_SetString(PyExc_RuntimeError, "Bisection state is not initialized");
    return NULL;
  }
  if (diana_bisection_result(&self->s, &root, &width) != DIANA_OK) {
    PyErr_SetString(PyExc_RuntimeError, "invalid Bisection state");
    return NULL;
  }
  return Py_BuildValue("(dd)", root, width);
}
