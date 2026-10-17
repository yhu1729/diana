#include "bisection_object.h"

int diana_py_bisection_init(BisectionObject *self, PyObject *args,
                            PyObject *kwds) {
  static char *kwlist[] = {"a", "b", "fa", "fb", "tol", "max_iter", NULL};
  double a, b, fa, fb, tol = 0.0;
  unsigned int max_iter = 2100u;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "dddd|dO&:Bisection", kwlist, &a,
                                   &b, &fa, &fb, &tol, diana_py_convert_uint,
                                   &max_iter)) {
    return -1;
  }
  st = diana_bisection_init(&self->s, a, b, fa, fb, tol, max_iter);
  if (st != DIANA_OK && st != DIANA_CONTINUE) {
    diana_py_raise(st, NULL);
    return -1;
  }
  self->status = (int)st;
  return 0;
}
