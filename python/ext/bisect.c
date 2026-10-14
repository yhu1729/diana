#include <stddef.h>

#include "module.h"

typedef struct {
  PyObject_HEAD
  diana_bisect_state s;
  int status;
} BisectObject;

static PyObject *bisect_new(PyTypeObject *type, PyObject *args,
                            PyObject *kwds) {
  BisectObject *self = (BisectObject *)PyType_GenericNew(type, args, kwds);
  if (self != NULL) {
    self->status = DIANA_ERR_ARG;
  }
  return (PyObject *)self;
}

static int bisect_init(BisectObject *self, PyObject *args, PyObject *kwds) {
  static char *kwlist[] = {"a", "b", "fa", "fb", "tol", "max_iter", NULL};
  double a, b, fa, fb, tol = 0.0;
  unsigned int max_iter = 2100u;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "dddd|dO&:Bisect", kwlist, &a,
                                   &b, &fa, &fb, &tol, diana_py_convert_uint,
                                   &max_iter)) {
    return -1;
  }
  st = diana_bisect_init(&self->s, a, b, fa, fb, tol, max_iter);
  if (st != DIANA_OK && st != DIANA_CONTINUE) {
    diana_py_raise(st, NULL);
    return -1;
  }
  self->status = (int)st;
  return 0;
}

static PyObject *bisect_step(BisectObject *self, PyObject *arg) {
  double fx;
  diana_status st;
  if (self->status == DIANA_ERR_ARG) {
    PyErr_SetString(PyExc_RuntimeError, "Bisect state is not initialized");
    return NULL;
  }
  fx = PyFloat_AsDouble(arg);
  if (fx == -1.0 && PyErr_Occurred()) {
    return NULL;
  }
  if (self->status != DIANA_CONTINUE) {
    PyErr_SetString(PyExc_RuntimeError,
                    "step called on a finished Bisect state");
    return NULL;
  }
  st = diana_bisect_step(&self->s, fx);
  if (st == DIANA_ERR_ARG) {
    diana_py_raise(st, "f(x) must be finite");
    return NULL;
  }
  self->status = (int)st;
  return PyLong_FromLong((long)st);
}

static PyObject *bisect_result(BisectObject *self,
                               PyObject *Py_UNUSED(ignored)) {
  double root, width;
  if (self->status == DIANA_ERR_ARG) {
    PyErr_SetString(PyExc_RuntimeError, "Bisect state is not initialized");
    return NULL;
  }
  if (diana_bisect_result(&self->s, &root, &width) != DIANA_OK) {
    PyErr_SetString(PyExc_RuntimeError, "invalid Bisect state");
    return NULL;
  }
  return Py_BuildValue("(dd)", root, width);
}

static PyMethodDef bisect_method[] = {
    {"step", (PyCFunction)bisect_step, METH_O,
     "step(fx) -> status\n\nConsume f(x) at the current x and halve the "
     "bracket."},
    {"result", (PyCFunction)bisect_result, METH_NOARGS,
     "result() -> (root, width)\n\nCurrent estimate 0.5*(a+b) and bracket "
     "width b-a."},
    {NULL, NULL, 0, NULL}};

static PyMemberDef bisect_member[] = {
    {"a", Py_T_DOUBLE, offsetof(BisectObject, s.a), Py_READONLY,
     "lower bracket endpoint"},
    {"b", Py_T_DOUBLE, offsetof(BisectObject, s.b), Py_READONLY,
     "upper bracket endpoint"},
    {"fa", Py_T_DOUBLE, offsetof(BisectObject, s.fa), Py_READONLY, "f(a)"},
    {"fb", Py_T_DOUBLE, offsetof(BisectObject, s.fb), Py_READONLY, "f(b)"},
    {"x", Py_T_DOUBLE, offsetof(BisectObject, s.x), Py_READONLY,
     "next evaluation point"},
    {"tol", Py_T_DOUBLE, offsetof(BisectObject, s.tol), Py_READONLY,
     "width tolerance"},
    {"iter", Py_T_UINT, offsetof(BisectObject, s.iter), Py_READONLY,
     "steps performed"},
    {"max_iter", Py_T_UINT, offsetof(BisectObject, s.max_iter), Py_READONLY,
     "step limit"},
    {"status", Py_T_INT, offsetof(BisectObject, status), Py_READONLY,
     "last status code"},
    {NULL, 0, 0, 0, NULL}};

static PyTypeObject BisectType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "diana._diana.Bisect",
    .tp_basicsize = sizeof(BisectObject),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT,
    .tp_doc = "Bisect(a, b, fa, fb, tol=0.0, max_iter=2100)\n\n"
              "Reverse-communication bisection state. Evaluate f at .x, call "
              ".step(fx) while the "
              "status is CONTINUE, then .result().",
    .tp_methods = bisect_method,
    .tp_members = bisect_member,
    .tp_init = (initproc)bisect_init,
    .tp_new = bisect_new,
};

int diana_py_bisect_exec(PyObject *m) {
  if (PyType_Ready(&BisectType) < 0) {
    return -1;
  }
  return PyModule_AddObjectRef(m, "Bisect", (PyObject *)&BisectType);
}
