#include <stddef.h>

#include "diana/axpy.h"
#include "fp.h"

/*@ requires x == \null || y == \null || n == 0 ||
  @          (\valid_read(x + (0 .. n - 1)) && \valid(y + (0 .. n - 1)) &&
  @           \separated(y + (0 .. n - 1), x + (0 .. n - 1)));
  @ assigns y[0 .. n - 1];
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_ARG ||
  @         \result == DIANA_ERR_OVERFLOW;
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_OVERFLOW ==>
  @         x != \null && y != \null && \is_finite(a);
  @ ensures \result == DIANA_ERR_OVERFLOW ==>
  @         \forall integer j; 0 <= j < n ==> \is_finite(x[j]) && \is_finite(y[j]);
  @ ensures \result == DIANA_ERR_ARG ==>
  @         x == \null || y == \null || !\is_finite(a) ||
  @         \exists integer j; 0 <= j < n && (!\is_finite(x[j]) || !\is_finite(y[j]));
  @ ensures (\result == DIANA_ERR_ARG || \result == DIANA_ERR_OVERFLOW) && y != \null ==>
  @         \forall integer j; 0 <= j < n ==> y[j] == \old(y[j]);
  @*/
diana_status diana_axpy(double a, const double *x, size_t n, double *y) {
  double r;
  size_t i;
  size_t j;

  if (x == (const double *)0 || y == (double *)0) {
    return DIANA_ERR_ARG;
  }
  if (!diana_fp_finite(a)) {
    return DIANA_ERR_ARG;
  }

  /*@ loop invariant 0 <= i <= n;
    @ loop assigns i, j, r;
    @ loop variant n - i;
    @*/
  for (i = 0u; i < n; ++i) {
    r = y[i] + a * x[i];
    if (!diana_fp_finite(r)) {
      /*@ loop invariant 0 <= j <= n;
        @ loop invariant \forall integer p; 0 <= p < j ==>
        @                \is_finite(x[p]) && \is_finite(y[p]);
        @ loop assigns j;
        @ loop variant n - j;
        @*/
      for (j = 0u; j < n; ++j) {
        if (!diana_fp_finite(x[j])) {
          return DIANA_ERR_ARG;
        }
        if (!diana_fp_finite(y[j])) {
          return DIANA_ERR_ARG;
        }
      }
      return DIANA_ERR_OVERFLOW;
    }
  }

  /*@ loop invariant 0 <= i <= n;
    @ loop assigns i, r, y[0 .. n - 1];
    @ loop variant n - i;
    @*/
  for (i = 0u; i < n; ++i) {
    r = y[i] + a * x[i];
    y[i] = r;
  }
  return DIANA_OK;
}
