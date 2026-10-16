#include <math.h>
#include <stddef.h>

#include "module.h"

typedef struct {
  PyObject_HEAD
  diana_newton_state s;
  int status;
} NewtonObject;

static PyObject *newton_new(PyTypeObject *type, PyObject *args,
                            PyObject *kwds) {
  NewtonObject *self = (NewtonObject *)PyType_GenericNew(type, args, kwds);
  if (self != NULL) {
    self->status = DIANA_ERR_ARG;
  }
  return (PyObject *)self;
}

static int newton_init(NewtonObject *self, PyObject *args, PyObject *kwds) {
  static char *kwlist[] = {"x0", "tol", "max_iter", NULL};
  double x0, tol;
  unsigned int max_iter = 100u;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "dd|O&:Newton", kwlist, &x0,
                                   &tol, diana_py_convert_uint, &max_iter)) {
    return -1;
  }
  st = diana_newton_init(&self->s, x0, tol, max_iter);
  if (st != DIANA_CONTINUE) {
    diana_py_raise(st, NULL);
    return -1;
  }
  self->status = (int)st;
  return 0;
}

static PyObject *newton_step(NewtonObject *self, PyObject *args) {
  double fx, dfx;
  diana_status st;
  const char *msg;
  if (self->status == DIANA_ERR_ARG) {
    PyErr_SetString(PyExc_RuntimeError, "Newton state is not initialized");
    return NULL;
  }
  if (!PyArg_ParseTuple(args, "dd:step", &fx, &dfx)) {
    return NULL;
  }
  if (self->status != DIANA_CONTINUE) {
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
    if (!isfinite(fx) || !isfinite(dfx)) {
      msg = "f(x) and f'(x) must be finite";
    } else {
      msg = "Newton step is not finite";
    }
    diana_py_raise(st, msg);
    return NULL;
  }
  self->status = (int)st;
  return PyLong_FromLong((long)st);
}

static PyObject *newton_result(NewtonObject *self,
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

static PyMethodDef newton_method[] = {
    {"step", (PyCFunction)newton_step, METH_VARARGS,
     "step(fx, dfx) -> status\n\nConsume f(x) and f'(x) at the current x and "
     "move x by f(x)/f'(x)."},
    {"result", (PyCFunction)newton_result, METH_NOARGS,
     "result() -> (root, dx)\n\nCurrent iterate x and the last correction "
     "f(x)/f'(x)."},
    {NULL, NULL, 0, NULL}};

static PyMemberDef newton_member[] = {
    {"x", Py_T_DOUBLE, offsetof(NewtonObject, s.x), Py_READONLY,
     "current iterate and next evaluation point"},
    {"dx", Py_T_DOUBLE, offsetof(NewtonObject, s.dx), Py_READONLY,
     "last correction f(x)/f'(x)"},
    {"tol", Py_T_DOUBLE, offsetof(NewtonObject, s.tol), Py_READONLY,
     "correction tolerance"},
    {"iter", Py_T_UINT, offsetof(NewtonObject, s.iter), Py_READONLY,
     "steps performed"},
    {"max_iter", Py_T_UINT, offsetof(NewtonObject, s.max_iter), Py_READONLY,
     "step limit"},
    {"status", Py_T_INT, offsetof(NewtonObject, status), Py_READONLY,
     "last status code"},
    {NULL, 0, 0, 0, NULL}};

static PyTypeObject NewtonType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "diana._diana.Newton",
    .tp_basicsize = sizeof(NewtonObject),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT,
    .tp_doc = "Newton(x0, tol, max_iter=100)\n\n"
              "Reverse-communication Newton state. Evaluate f and f' at .x, "
              "call .step(fx, dfx) while the status is CONTINUE, then "
              ".result().",
    .tp_methods = newton_method,
    .tp_members = newton_member,
    .tp_init = (initproc)newton_init,
    .tp_new = newton_new,
};

int diana_py_newton_exec(PyObject *m) {
  if (PyType_Ready(&NewtonType) < 0) {
    return -1;
  }
  return PyModule_AddObjectRef(m, "Newton", (PyObject *)&NewtonType);
}
