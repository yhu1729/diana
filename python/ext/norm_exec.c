#include "module.h"

static PyMethodDef norm_method[] = {
    {"norm_1", (PyCFunction)(void (*)(void))diana_py_norm_1,
     METH_VARARGS | METH_KEYWORDS,
     "norm_1(x) -> float\n\n1-norm |x[0]| + ... + |x[n-1]|, added left to "
     "right, of a one-dimensional, C-contiguous, aligned buffer x of native "
     "float64, read in place; 0.0 for an empty x."},
    {"norm_2", (PyCFunction)(void (*)(void))diana_py_norm_2,
     METH_VARARGS | METH_KEYWORDS,
     "norm_2(x) -> float\n\nEuclidean norm sqrt(x[0]**2 + ... + x[n-1]**2) of "
     "a one-dimensional, C-contiguous, aligned buffer x of native float64, "
     "read in place, computed as m * sqrt(s) with m = max |x[i]| and s the sum "
     "of the squares of x[i] / m, so no square overflows or underflows; 0.0 "
     "for an empty x."},
    {"norm_inf", (PyCFunction)(void (*)(void))diana_py_norm_inf,
     METH_VARARGS | METH_KEYWORDS,
     "norm_inf(x) -> float\n\nMaximum norm max |x[i]|, exact, of a "
     "one-dimensional, C-contiguous, aligned buffer x of native float64, read "
     "in place; 0.0 for an empty x."},
    {NULL, NULL, 0, NULL}};

int diana_py_norm_exec(PyObject *m) {
  return PyModule_AddFunctions(m, norm_method);
}
