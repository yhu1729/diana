#include <stddef.h>

#include "newton_object.h"

static PyMethodDef newton_method[] = {
    {"step", (PyCFunction)diana_py_newton_step, METH_VARARGS,
     "step(fx, dfx) -> status\n\nConsume f(x) and f'(x) at the current x and "
     "move x by f(x)/f'(x)."},
    {"result", (PyCFunction)diana_py_newton_result, METH_NOARGS,
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
    {"status", Py_T_INT, offsetof(NewtonObject, s.status), Py_READONLY,
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
    .tp_init = (initproc)diana_py_newton_init,
    .tp_new = diana_py_newton_new,
};

int diana_py_newton_exec(PyObject *m) {
  if (PyType_Ready(&NewtonType) < 0) {
    return -1;
  }
  return PyModule_AddObjectRef(m, "Newton", (PyObject *)&NewtonType);
}
