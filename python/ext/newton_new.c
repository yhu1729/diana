#include "newton_object.h"

PyObject *diana_py_newton_new(PyTypeObject *type, PyObject *args,
                              PyObject *kwds) {
  NewtonObject *self = (NewtonObject *)PyType_GenericNew(type, args, kwds);
  if (self != NULL) {
    self->s.status = DIANA_ERR_ARG;
  }
  return (PyObject *)self;
}
