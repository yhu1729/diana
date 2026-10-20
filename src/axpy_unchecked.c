#include <stddef.h>

#include "diana/axpy.h"

/*@ requires x == \null || y == \null || n == 0 ||
  @          (\valid_read(x + (0 .. n - 1)) && \valid(y + (0 .. n - 1)) &&
  @           \separated(y + (0 .. n - 1), x + (0 .. n - 1)));
  @ assigns y[0 .. n - 1];
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_ARG;
  @ ensures \result == DIANA_OK <==> x != \null && y != \null;
  @ ensures \result == DIANA_ERR_ARG && y != \null ==>
  @         \forall integer j; 0 <= j < n ==> y[j] == \old(y[j]);
  @*/
diana_status diana_axpy_unchecked(double a, const double *x, size_t n,
                                  double *y) {
  size_t i;

  if (x == (const double *)0 || y == (double *)0) {
    return DIANA_ERR_ARG;
  }

  /*@ loop invariant 0 <= i <= n;
    @ loop assigns i, y[0 .. n - 1];
    @ loop variant n - i;
    @*/
  for (i = 0u; i < n; ++i) {
    y[i] = y[i] + a * x[i];
  }
  return DIANA_OK;
}
