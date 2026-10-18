#include "module.h"

static PyMethodDef lu_method[] = {
    {"lu", (PyCFunction)(void (*)(void))diana_py_lu,
     METH_VARARGS | METH_KEYWORDS,
     "lu(a, out) -> list[int]\n\nLU factorization with partial pivoting, "
     "P * A = L * U, of an n x n matrix stored column-major, "
     "a[i + j*n] = A[i, j], in a one-dimensional, C-contiguous, aligned "
     "buffer of n*n native float64, read in place. out, writable, of the "
     "same length and separate from a, receives L below the diagonal (its "
     "unit diagonal is not stored) and U on and above it, column-major; it "
     "is untouched when a has a non-finite entry and unspecified after a "
     "zero pivot or an overflow. Returns the pivot rows piv: at step k, row "
     "k was swapped with row piv[k] >= k."},
    {NULL, NULL, 0, NULL}};

int diana_py_lu_exec(PyObject *m) {
  return PyModule_AddFunctions(m, lu_method);
}
