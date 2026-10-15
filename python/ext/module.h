#ifndef DIANA_PY_MODULE_H
#define DIANA_PY_MODULE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#include "diana/diana.h"

extern PyObject *diana_py_bracket_error;

void diana_py_raise(diana_status st, const char *msg);

int diana_py_convert_uint(PyObject *obj, void *out);

int diana_py_status_exec(PyObject *m);
int diana_py_bisection_exec(PyObject *m);
int diana_py_trapezoidal_exec(PyObject *m);

PyMODINIT_FUNC PyInit__diana(void);

#endif
