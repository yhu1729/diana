#include <stddef.h>

#include "diana/norm.h"
#include "fp.h"

/*@ requires x == \null || n == 0 || \valid_read(x + (0 .. n - 1));
  @ requires result == \null || \valid(result);
  @ requires x == \null || result == \null || n == 0 ||
  @          \separated(result, x + (0 .. n - 1));
  @ assigns *result;
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_ARG;
  @ ensures \result == DIANA_OK ==> x != \null && result != \null;
  @ ensures \result == DIANA_OK ==> \forall integer q; 0 <= q < n ==> \is_finite(x[q]);
  @ ensures \result == DIANA_OK ==> \is_finite(*result) && *result >= 0.0;
  @ ensures \result == DIANA_OK ==> \forall integer q; 0 <= q < n ==> \abs(x[q]) <= *result;
  @ ensures \result == DIANA_OK ==>
  @         *result == 0.0 || \exists integer q; 0 <= q < n && *result == \abs(\old(x[q]));
  @ ensures \result == DIANA_ERR_ARG ==>
  @         x == \null || result == \null ||
  @         \exists integer q; 0 <= q < n && !\is_finite(x[q]);
  @ ensures \result == DIANA_ERR_ARG && result != \null ==> *result == \old(*result);
  @*/
diana_status diana_norm_inf(const double *x, size_t n, double *result) {
  double m;
  double a;
  size_t i;

  if (x == (const double *)0 || result == (double *)0) {
    return DIANA_ERR_ARG;
  }

  m = 0.0;
  /*@ loop invariant 0 <= i <= n;
    @ loop invariant \forall integer q; 0 <= q < i ==> \is_finite(x[q]);
    @ loop invariant \is_finite(m) && m >= 0.0;
    @ loop invariant \forall integer q; 0 <= q < i ==> \abs(x[q]) <= m;
    @ loop invariant m == 0.0 || \exists integer q; 0 <= q < i && m == \abs(x[q]);
    @ loop assigns i, m, a;
    @ loop variant n - i;
    @*/
  for (i = 0u; i < n; ++i) {
    if (!diana_fp_finite(x[i])) {
      return DIANA_ERR_ARG;
    }
    a = diana_fp_abs(x[i]);
    if (a > m) {
      m = a;
    }
  }
  *result = m;
  return DIANA_OK;
}
