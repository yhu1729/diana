#ifndef DIANA_PY_MODULE_H
#define DIANA_PY_MODULE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#include <stdint.h>

#include "diana/diana.h"

extern PyObject *diana_py_bracket_error;
extern PyObject *diana_py_singular_error;

void diana_py_raise(diana_status st, const char *msg);

int diana_py_convert_uint(PyObject *obj, void *out);
int diana_py_get_array(PyObject *obj, Py_buffer *view, const char *name,
                       int writable, Py_ssize_t min_count,
                       const char *count_message);

static inline int diana_py_overlap(const Py_buffer *a, const Py_buffer *b) {
  uintptr_t a0 = (uintptr_t)a->buf;
  uintptr_t b0 = (uintptr_t)b->buf;
  return a0 < b0 + (uintptr_t)b->len && b0 < a0 + (uintptr_t)a->len;
}

PyObject *diana_py_version(PyObject *self, PyObject *ignored);
PyObject *diana_py_status_str(PyObject *self, PyObject *arg);
PyObject *diana_py_cholesky(PyObject *self, PyObject *args, PyObject *kwds);
PyObject *diana_py_euler_step(PyObject *self, PyObject *args, PyObject *kwds);
PyObject *diana_py_rk4_stage(PyObject *self, PyObject *args, PyObject *kwds);
PyObject *diana_py_rk4_step(PyObject *self, PyObject *args, PyObject *kwds);
PyObject *diana_py_simpson(PyObject *self, PyObject *args, PyObject *kwds);
PyObject *diana_py_trapezoidal(PyObject *self, PyObject *args, PyObject *kwds);

int diana_py_status_exec(PyObject *m);
int diana_py_bisection_exec(PyObject *m);
int diana_py_cholesky_exec(PyObject *m);
int diana_py_euler_exec(PyObject *m);
int diana_py_newton_exec(PyObject *m);
int diana_py_rk4_exec(PyObject *m);
int diana_py_simpson_exec(PyObject *m);
int diana_py_trapezoidal_exec(PyObject *m);

PyMODINIT_FUNC PyInit__diana(void);

#endif
