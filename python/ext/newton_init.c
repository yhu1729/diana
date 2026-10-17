#include "newton_object.h"

int diana_py_newton_init(NewtonObject *self, PyObject *args, PyObject *kwds) {
  static char *kwlist[] = {"x0", "tol", "max_iter", NULL};
  double x0, tol;
  unsigned int max_iter = 100u;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "dd|O&:Newton", kwlist, &x0,
                                   &tol, diana_py_convert_uint, &max_iter)) {
    return -1;
  }
  st = diana_newton_init(&self->s, x0, tol, max_iter);
  if (st != DIANA_CONTINUE) {
    diana_py_raise(st, NULL);
    return -1;
  }
  self->status = (int)st;
  return 0;
}
