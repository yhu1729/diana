#include "module.h"

static PyMethodDef cholesky_method[] = {
    {"cholesky", (PyCFunction)(void (*)(void))diana_py_cholesky,
     METH_VARARGS | METH_KEYWORDS,
     "cholesky(a, out) -> None\n\nCholesky factorization A = L * L^T of a "
     "symmetric positive definite n x n matrix stored column-major, "
     "a[i + j*n] = A[i, j], in a one-dimensional, C-contiguous, aligned "
     "buffer of n*n native float64; only entries on or below the diagonal "
     "are read, in place. out, writable, of the same length and separate "
     "from a, receives L column-major with its strict upper triangle zero; "
     "it is untouched on an argument error and unspecified when the matrix "
     "is not positive definite."},
    {NULL, NULL, 0, NULL}};

int diana_py_cholesky_exec(PyObject *m) {
  return PyModule_AddFunctions(m, cholesky_method);
}
