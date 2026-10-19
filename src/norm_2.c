#include <stddef.h>

#include "diana/norm.h"
#include "fp.h"
#include "fp_sqrt.h"

/*@ requires x == \null || n == 0 || \valid_read(x + (0 .. n - 1));
  @ requires result == \null || \valid(result);
  @ requires x == \null || result == \null || n == 0 ||
  @          \separated(result, x + (0 .. n - 1));
  @ assigns *result;
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_ARG ||
  @         \result == DIANA_ERR_OVERFLOW;
  @ ensures \result == DIANA_OK ==> x != \null && result != \null;
  @ ensures \result == DIANA_OK ==> \forall integer q; 0 <= q < n ==> \is_finite(x[q]);
  @ ensures \result == DIANA_OK ==> \is_finite(*result);
  @ ensures \result == DIANA_OK ==> \forall integer q; 0 <= q < n ==> \abs(x[q]) <= *result;
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
diana_status diana_norm_2(const double *x, size_t n, double *result) {
  double m;
  double a;
  double q;
  double s;
  double t;
  double r;
  size_t i;
  size_t k;

  if (x == (const double *)0 || result == (double *)0) {
    return DIANA_ERR_ARG;
  }

  m = 0.0;
  k = 0u;
  /*@ loop invariant 0 <= i <= n;
    @ loop invariant \forall integer q; 0 <= q < i ==> \is_finite(x[q]);
    @ loop invariant \is_finite(m) && m >= 0.0;
    @ loop invariant \forall integer q; 0 <= q < i ==> \abs(x[q]) <= m;
    @ loop invariant 0 <= k <= i;
    @ loop invariant m == 0.0 || (k < i && m == \abs(x[k]));
    @ loop assigns i, m, a, k;
    @ loop variant n - i;
    @*/
  for (i = 0u; i < n; ++i) {
    if (!diana_fp_finite(x[i])) {
      return DIANA_ERR_ARG;
    }
    a = diana_fp_abs(x[i]);
    if (a > m) {
      m = a;
      k = i;
    }
  }
  if (m == 0.0) {
    *result = 0.0;
    return DIANA_OK;
  }

  s = 1.0;
  /*@ loop invariant 0 <= i <= n;
    @ loop invariant \ge_double(s, (double)1.0);
    @ loop assigns i, q, s;
    @ loop variant n - i;
    @*/
  for (i = 0u; i < n; ++i) {
    if (i != k) {
      q = x[i] / m;
      s = s + q * q;
    }
  }
  t = diana_fp_sqrt(s);
  r = m * t;
  if (!diana_fp_finite(r)) {
    return DIANA_ERR_OVERFLOW;
  }
  /*@ assert \is_finite(t); */
  /*@ assert \is_finite(s); */
  /*@ assert t >= 1.0; */
  /*@ assert m * t >= m; */
  /*@ assert r == \round_double(\NearestEven, m * t); */
  /*@ assert \round_double(\NearestEven, m) == m; */
  /*@ assert \round_double(\NearestEven, m * t) >= \round_double(\NearestEven, m); */
  *result = r;
  return DIANA_OK;
}
