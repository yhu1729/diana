#include <stddef.h>

#include "bisection_object.h"

static PyMethodDef bisection_method[] = {
    {"step", (PyCFunction)diana_py_bisection_step, METH_O,
     "step(fx) -> status\n\nConsume f(x) at the current x and halve the "
     "bracket."},
    {"result", (PyCFunction)diana_py_bisection_result, METH_NOARGS,
     "result() -> (root, width)\n\nCurrent estimate 0.5*(a+b) and bracket "
     "width b-a."},
    {NULL, NULL, 0, NULL}};

static PyMemberDef bisection_member[] = {
    {"a", Py_T_DOUBLE, offsetof(BisectionObject, s.a), Py_READONLY,
     "lower bracket endpoint"},
    {"b", Py_T_DOUBLE, offsetof(BisectionObject, s.b), Py_READONLY,
     "upper bracket endpoint"},
    {"fa", Py_T_DOUBLE, offsetof(BisectionObject, s.fa), Py_READONLY, "f(a)"},
    {"fb", Py_T_DOUBLE, offsetof(BisectionObject, s.fb), Py_READONLY, "f(b)"},
    {"x", Py_T_DOUBLE, offsetof(BisectionObject, s.x), Py_READONLY,
     "next evaluation point"},
    {"tol", Py_T_DOUBLE, offsetof(BisectionObject, s.tol), Py_READONLY,
     "width tolerance"},
    {"iter", Py_T_UINT, offsetof(BisectionObject, s.iter), Py_READONLY,
     "steps performed"},
    {"max_iter", Py_T_UINT, offsetof(BisectionObject, s.max_iter), Py_READONLY,
     "step limit"},
    {"status", Py_T_INT, offsetof(BisectionObject, s.status), Py_READONLY,
     "last status code"},
    {NULL, 0, 0, 0, NULL}};

static PyTypeObject BisectionType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "diana._diana.Bisection",
    .tp_basicsize = sizeof(BisectionObject),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT,
    .tp_doc = "Bisection(a, b, fa, fb, tol=0.0, max_iter=2100)\n\n"
              "Reverse-communication bisection state. Evaluate f at .x, call "
              ".step(fx) while the "
              "status is CONTINUE, then .result().",
    .tp_methods = bisection_method,
    .tp_members = bisection_member,
    .tp_init = (initproc)diana_py_bisection_init,
    .tp_new = diana_py_bisection_new,
};

int diana_py_bisection_exec(PyObject *m) {
  if (PyType_Ready(&BisectionType) < 0) {
    return -1;
  }
  return PyModule_AddObjectRef(m, "Bisection", (PyObject *)&BisectionType);
}
