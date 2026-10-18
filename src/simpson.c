#include <stddef.h>

#include "diana/simpson.h"
#include "fp.h"

/*@ requires y == \null || n < 3 || \valid_read(y + (0 .. n - 1));
  @ requires result == \null || \valid(result);
  @ requires y == \null || result == \null || n < 3 ||
  @          \separated(result, y + (0 .. n - 1));
  @ assigns *result;
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_ARG ||
  @         \result == DIANA_ERR_OVERFLOW;
  @ ensures \result == DIANA_OK ==>
  @         y != \null && result != \null && n >= 3 && n % 2 == 1 &&
  @         \is_finite(*result);
  @ ensures \result == DIANA_ERR_OVERFLOW ==>
  @         y != \null && result != \null && n >= 3 && \is_finite(h) &&
  @         \forall integer q; 0 <= q < n ==> \is_finite(y[q]);
  @ ensures (\result == DIANA_ERR_ARG || \result == DIANA_ERR_OVERFLOW) && result != \null ==>
  @         *result == \old(*result);
  @*/
diana_status diana_simpson(const double *y, size_t n, double h,
                           double *result) {
  double so;
  double se;
  double s;
  double r;
  size_t p;
  size_t k;

  if (y == (const double *)0 || result == (double *)0 || n < 3u ||
      n % 2u == 0u) {
    return DIANA_ERR_ARG;
  }

  p = n / 2u;
  /*@ assert n == 2 * p + 1; */
  so = 0.0;
  /*@ loop invariant 0 <= k <= p;
    @ loop assigns k, so;
    @ loop variant p - k;
    @*/
  for (k = 0u; k < p; ++k) {
    so = so + y[2u * k + 1u];
  }
  se = 0.0;
  /*@ loop invariant 1 <= k <= p;
    @ loop assigns k, se;
    @ loop variant p - k;
    @*/
  for (k = 1u; k < p; ++k) {
    se = se + y[2u * k];
  }

  s = ((y[0] + y[n - 1u]) + 4.0 * so) + 2.0 * se;
  r = h * s / 3.0;
  if (!diana_fp_finite(r)) {
    if (!diana_fp_finite(h)) {
      return DIANA_ERR_ARG;
    }
    /*@ loop invariant 0 <= k <= n;
      @ loop invariant \forall integer q; 0 <= q < k ==> \is_finite(y[q]);
      @ loop assigns k;
      @ loop variant n - k;
      @*/
    for (k = 0u; k < n; ++k) {
      if (!diana_fp_finite(y[k])) {
        return DIANA_ERR_ARG;
      }
    }
    return DIANA_ERR_OVERFLOW;
  }
  *result = r;
  return DIANA_OK;
}
