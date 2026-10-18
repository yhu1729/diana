#ifndef DIANA_PY_BISECTION_OBJECT_H
#define DIANA_PY_BISECTION_OBJECT_H

#include "module.h"

typedef struct {
  PyObject_HEAD
  diana_bisection_state s;
} BisectionObject;

PyObject *diana_py_bisection_new(PyTypeObject *type, PyObject *args,
                                 PyObject *kwds);

int diana_py_bisection_init(BisectionObject *self, PyObject *args,
                            PyObject *kwds);

PyObject *diana_py_bisection_step(BisectionObject *self, PyObject *arg);

PyObject *diana_py_bisection_result(BisectionObject *self, PyObject *ignored);

#endif
