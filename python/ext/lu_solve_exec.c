#include "module.h"

static PyMethodDef lu_solve_method[] = {
    {"lu_solve", (PyCFunction)(void (*)(void))diana_py_lu_solve,
     METH_VARARGS | METH_KEYWORDS,
     "lu_solve(lu, piv, b, out) -> None\n\nSolve A * x = b from the LU "
     "factorization P * A = L * U that lu() returns: lu holds L strictly "
     "below the diagonal (its unit diagonal is not stored) and U on and "
     "above it, column-major (lu[i + j*n] is entry (i, j)), in a "
     "one-dimensional, C-contiguous, aligned buffer of n*n native float64 "
     "read in place, and "
     "piv, an iterable of n int, the pivot rows. b holds n samples. The rows "
     "k and piv[k] of b are swapped for k = 0, 1, ..., n-1, then L * y = P "
     "* b and U * x = y are solved. out, writable, of length n and separate "
     "from lu and b, receives x; it is untouched when an entry is not finite, "
     "a pivot row is not below n or U has a zero on the diagonal, and "
     "unspecified when the solution overflows."},
    {NULL, NULL, 0, NULL}};

int diana_py_lu_solve_exec(PyObject *m) {
  return PyModule_AddFunctions(m, lu_solve_method);
}
