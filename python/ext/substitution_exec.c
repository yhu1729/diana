#include "module.h"

static PyMethodDef substitution_method[] = {
    {"forward_substitution",
     (PyCFunction)(void (*)(void))diana_py_forward_substitution,
     METH_VARARGS | METH_KEYWORDS,
     "forward_substitution(lower, b, out) -> None\n\nSolve L * x = b by "
     "forward "
     "substitution for an n x n lower-triangular L stored column-major, "
     "lower[i + j*n] = L[i, j], in a one-dimensional, C-contiguous, aligned "
     "buffer of n*n native float64; only entries on or below the diagonal "
     "are read, in place, and b holds n of them. out, writable, of length n "
     "and separate from lower and b, receives x; it is untouched when an entry "
     "is not finite or the diagonal has a zero, and unspecified when the "
     "solution overflows."},
    {"back_substitution",
     (PyCFunction)(void (*)(void))diana_py_back_substitution,
     METH_VARARGS | METH_KEYWORDS,
     "back_substitution(lower, b, out) -> None\n\nSolve L^T * x = b by back "
     "substitution for an n x n lower-triangular L stored column-major, "
     "lower[i + j*n] = L[i, j], in a one-dimensional, C-contiguous, aligned "
     "buffer of n*n native float64; only entries on or below the diagonal "
     "are read, in place, and b holds n of them. out, writable, of length n "
     "and separate from lower and b, receives x; it is untouched when an entry "
     "is not finite or the diagonal has a zero, and unspecified when the "
     "solution overflows."},
    {NULL, NULL, 0, NULL}};

int diana_py_substitution_exec(PyObject *m) {
  return PyModule_AddFunctions(m, substitution_method);
}
