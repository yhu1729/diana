#include <stddef.h>

#include "diana/trapezoidal.h"
#include "fp.h"

/*@ requires y == \null || n < 2 || \valid_read(y + (0 .. n - 1));
  @ requires result == \null || \valid(result);
  @ requires y == \null || result == \null || n < 2 ||
  @          \separated(result, y + (0 .. n - 1));
  @ assigns *result;
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_ARG ||
  @         \result == DIANA_ERR_OVERFLOW;
  @ ensures \result == DIANA_OK ==>
  @         y != \null && result != \null && n >= 2 && \is_finite(*result);
  @ ensures \result == DIANA_ERR_OVERFLOW ==>
  @         y != \null && result != \null && n >= 2 && \is_finite(h) &&
  @         \forall integer q; 0 <= q < n ==> \is_finite(y[q]);
  @ ensures (\result == DIANA_ERR_ARG || \result == DIANA_ERR_OVERFLOW) && result != \null ==>
  @         *result == \old(*result);
  @*/
diana_status diana_trapezoidal(const double *y, size_t n, double h,
                               double *result) {
  double s;
  double r;
  size_t i;

  if (y == (const double *)0 || result == (double *)0 || n < 2u) {
    return DIANA_ERR_ARG;
  }

  s = 0.5 * (y[0] + y[n - 1u]);
  /*@ loop invariant 1 <= i <= n - 1;
    @ loop assigns i, s;
    @ loop variant n - 1 - i;
    @*/
  for (i = 1u; i < n - 1u; ++i) {
    s = s + y[i];
  }

  r = h * s;
  if (!diana_fp_finite(r)) {
    if (!diana_fp_finite(h)) {
      return DIANA_ERR_ARG;
    }
    /*@ loop invariant 0 <= i <= n;
      @ loop invariant \forall integer q; 0 <= q < i ==> \is_finite(y[q]);
      @ loop assigns i;
      @ loop variant n - i;
      @*/
    for (i = 0u; i < n; ++i) {
      if (!diana_fp_finite(y[i])) {
        return DIANA_ERR_ARG;
      }
    }
    return DIANA_ERR_OVERFLOW;
  }
  *result = r;
  return DIANA_OK;
}
