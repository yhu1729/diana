#include "bisection_object.h"

PyObject *diana_py_bisection_step(BisectionObject *self, PyObject *arg) {
  double fx;
  diana_status st;
  if (self->status == DIANA_ERR_ARG) {
    PyErr_SetString(PyExc_RuntimeError, "Bisection state is not initialized");
    return NULL;
  }
  fx = PyFloat_AsDouble(arg);
  if (fx == -1.0 && PyErr_Occurred()) {
    return NULL;
  }
  if (self->status != DIANA_CONTINUE) {
    PyErr_SetString(PyExc_RuntimeError,
                    "step called on a finished Bisection state");
    return NULL;
  }
  st = diana_bisection_step(&self->s, fx);
  if (st == DIANA_ERR_ARG) {
    diana_py_raise(st, "f(x) must be finite");
    return NULL;
  }
  self->status = (int)st;
  return PyLong_FromLong((long)st);
}
