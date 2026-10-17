#include "newton_object.h"

PyObject *diana_py_newton_result(NewtonObject *self,
                                 PyObject *Py_UNUSED(ignored)) {
  double root, dx;
  if (self->status == DIANA_ERR_ARG) {
    PyErr_SetString(PyExc_RuntimeError, "Newton state is not initialized");
    return NULL;
  }
  if (diana_newton_result(&self->s, &root, &dx) != DIANA_OK) {
    PyErr_SetString(PyExc_RuntimeError, "invalid Newton state");
    return NULL;
  }
  return Py_BuildValue("(dd)", root, dx);
}
