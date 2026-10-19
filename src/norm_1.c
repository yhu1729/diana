#include <stddef.h>

#include "diana/norm.h"
#include "fp.h"

/*@ requires x == \null || n == 0 || \valid_read(x + (0 .. n - 1));
  @ requires result == \null || \valid(result);
  @ requires x == \null || result == \null || n == 0 ||
  @          \separated(result, x + (0 .. n - 1));
  @ assigns *result;
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_ARG ||
  @         \result == DIANA_ERR_OVERFLOW;
  @ ensures \result == DIANA_OK ==>
  @         x != \null && result != \null &&
  @         (\forall integer q; 0 <= q < n ==> \is_finite(x[q])) &&
  @         \is_finite(*result) && *result >= 0.0;
  @ ensures \result == DIANA_OK && n == 0 ==> *result == 0.0;
  @ ensures \result == DIANA_ERR_OVERFLOW ==>
  @         x != \null && result != \null &&
  @         \forall integer q; 0 <= q < n ==> \is_finite(x[q]);
  @ ensures \result == DIANA_ERR_ARG ==>
  @         x == \null || result == \null ||
  @         \exists integer q; 0 <= q < n && !\is_finite(x[q]);
  @ ensures (\result == DIANA_ERR_ARG || \result == DIANA_ERR_OVERFLOW) && result != \null ==>
  @         *result == \old(*result);
  @*/
diana_status diana_norm_1(const double *x, size_t n, double *result) {
  double s;
  size_t i;

  if (x == (const double *)0 || result == (double *)0) {
    return DIANA_ERR_ARG;
  }

  s = 0.0;
  /*@ loop invariant 0 <= i <= n;
    @ loop invariant \forall integer q; 0 <= q < i ==> \is_finite(x[q]);
    @ loop invariant \ge_double(s, (double)0.0);
    @ loop invariant i == 0 ==> s == 0.0;
    @ loop assigns i, s;
    @ loop variant n - i;
    @*/
  for (i = 0u; i < n; ++i) {
    if (!diana_fp_finite(x[i])) {
      return DIANA_ERR_ARG;
    }
    s = s + diana_fp_abs(x[i]);
  }
  if (!diana_fp_finite(s)) {
    return DIANA_ERR_OVERFLOW;
  }
  *result = s;
  return DIANA_OK;
}
