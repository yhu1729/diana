#include "module.h"

static PyMethodDef euler_method[] = {
    {"euler_step", (PyCFunction)(void (*)(void))diana_py_euler_step,
     METH_VARARGS | METH_KEYWORDS,
     "euler_step(y, f, h, out) -> None\n\nOne explicit Euler step "
     "out[i] = y[i] + h * f[i] over one-dimensional, C-contiguous, aligned "
     "buffers of native float64 of equal length; y and f are read in place "
     "and out, writable and separate from both, is written only on success."},
    {NULL, NULL, 0, NULL}};

int diana_py_euler_exec(PyObject *m) {
  return PyModule_AddFunctions(m, euler_method);
}
