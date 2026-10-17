#include "module.h"

static PyMethodDef simpson_method[] = {
    {"simpson", (PyCFunction)(void (*)(void))diana_py_simpson,
     METH_VARARGS | METH_KEYWORDS,
     "simpson(y, h) -> float\n\nComposite Simpson rule "
     "h/3 * (y[0] + 4*y[1] + 2*y[2] + ... + 4*y[n-2] + y[n-1]) over a "
     "one-dimensional, C-contiguous, aligned buffer y of an odd number of "
     "native float64, read in place."},
    {NULL, NULL, 0, NULL}};

int diana_py_simpson_exec(PyObject *m) {
  return PyModule_AddFunctions(m, simpson_method);
}
