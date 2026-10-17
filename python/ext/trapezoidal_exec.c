#include "module.h"

static PyMethodDef trapezoidal_method[] = {
    {"trapezoidal", (PyCFunction)(void (*)(void))diana_py_trapezoidal,
     METH_VARARGS | METH_KEYWORDS,
     "trapezoidal(y, h) -> float\n\nComposite trapezoidal rule "
     "h * (y[0]/2 + y[1] + ... + y[n-2] + y[n-1]/2) over a one-dimensional, "
     "C-contiguous, aligned buffer y of native float64, read in place."},
    {NULL, NULL, 0, NULL}};

int diana_py_trapezoidal_exec(PyObject *m) {
  return PyModule_AddFunctions(m, trapezoidal_method);
}
