#include "module.h"

static PyMethodDef axpy_method[] = {
    {"axpy", (PyCFunction)(void (*)(void))diana_py_axpy,
     METH_VARARGS | METH_KEYWORDS,
     "axpy(a, x, y) -> None\n\nThe update y[i] = y[i] + a * x[i] in place "
     "over one-dimensional, C-contiguous, aligned buffers of native float64 "
     "of equal length, empty included; x is read in place and y, writable "
     "and separate from x, is written only on success."},
    {NULL, NULL, 0, NULL}};

int diana_py_axpy_exec(PyObject *m) {
  return PyModule_AddFunctions(m, axpy_method);
}
