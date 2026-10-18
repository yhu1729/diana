#ifndef DIANA_PY_NEWTON_OBJECT_H
#define DIANA_PY_NEWTON_OBJECT_H

#include "module.h"

typedef struct {
  PyObject_HEAD
  diana_newton_state s;
} NewtonObject;

PyObject *diana_py_newton_new(PyTypeObject *type, PyObject *args,
                              PyObject *kwds);

int diana_py_newton_init(NewtonObject *self, PyObject *args, PyObject *kwds);

PyObject *diana_py_newton_step(NewtonObject *self, PyObject *args);

PyObject *diana_py_newton_result(NewtonObject *self, PyObject *ignored);

#endif
