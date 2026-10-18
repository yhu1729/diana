#include "newton_object.h"

PyObject *diana_py_newton_step(NewtonObject *self, PyObject *args) {
  double fx, dfx;
  diana_status st;
  if (self->s.status == DIANA_ERR_ARG) {
    PyErr_SetString(PyExc_RuntimeError, "Newton state is not initialized");
    return NULL;
  }
  if (!PyArg_ParseTuple(args, "dd:step", &fx, &dfx)) {
    return NULL;
  }
  if (self->s.status != DIANA_CONTINUE) {
    PyErr_SetString(PyExc_RuntimeError,
                    "step called on a finished Newton state");
    return NULL;
  }
  st = diana_newton_step(&self->s, fx, dfx);
  if (st == DIANA_ERR_SINGULAR) {
    diana_py_raise(st, "f'(x) is zero");
    return NULL;
  }
  if (st == DIANA_ERR_ARG) {
    diana_py_raise(st, "f(x) and f'(x) must be finite");
    return NULL;
  }
  if (st == DIANA_ERR_OVERFLOW) {
    diana_py_raise(st, "Newton step overflows");
    return NULL;
  }
  return PyLong_FromLong((long)st);
}
