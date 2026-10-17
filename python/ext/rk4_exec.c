#include "module.h"

static PyMethodDef rk4_method[] = {
    {"rk4_stage", (PyCFunction)(void (*)(void))diana_py_rk4_stage,
     METH_VARARGS | METH_KEYWORDS,
     "rk4_stage(y, k, h, stage, out) -> None\n\nThe RK4 stage point "
     "out[i] = y[i] + c * k[i], c = 0.5 * h for stage 2 or 3 and c = h for "
     "stage 4, over one-dimensional, C-contiguous, aligned buffers of native "
     "float64 of equal length; y and k are read in place and out, writable "
     "and separate from both, is written only on success."},
    {"rk4_step", (PyCFunction)(void (*)(void))diana_py_rk4_step,
     METH_VARARGS | METH_KEYWORDS,
     "rk4_step(y, k1, k2, k3, k4, h, out) -> None\n\nThe RK4 step "
     "out[i] = y[i] + h * ((k1[i] + k4[i]) + 2 * (k2[i] + k3[i])) / 6 over "
     "one-dimensional, C-contiguous, aligned buffers of native float64 of "
     "equal length; the inputs are read in place and out, writable and "
     "separate from all of them, is written only on success."},
    {NULL, NULL, 0, NULL}};

int diana_py_rk4_exec(PyObject *m) {
  return PyModule_AddFunctions(m, rk4_method);
}
