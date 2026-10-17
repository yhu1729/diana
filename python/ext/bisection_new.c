#include "bisection_object.h"

PyObject *diana_py_bisection_new(PyTypeObject *type, PyObject *args,
                                 PyObject *kwds) {
  BisectionObject *self =
      (BisectionObject *)PyType_GenericNew(type, args, kwds);
  if (self != NULL) {
    self->status = DIANA_ERR_ARG;
  }
  return (PyObject *)self;
}
