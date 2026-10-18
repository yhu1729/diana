#include <stddef.h>

#include "diana/substitution.h"
#include "fp.h"
#include "substitution_acsl.h"

/*@ requires l == \null || b == \null || x == \null || n == 0 ||
  @          n > 18446744073709551615 / n || substitution_valid(l, n, b, x);
  @ assigns x[0 .. n - 1];
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_ARG ||
  @         \result == DIANA_ERR_SINGULAR || \result == DIANA_ERR_OVERFLOW;
  @ ensures \result != DIANA_ERR_ARG ==>
  @         l != \null && b != \null && x != \null && n >= 1 &&
  @         n * n <= 18446744073709551615;
  @ ensures \result == DIANA_ERR_SINGULAR ==>
  @         \forall integer p; 0 <= p < n ==> x[p] == \old(x[p]);
  @ ensures \result == DIANA_OK ==>
  @         \forall integer p; 0 <= p < n ==> \is_finite(x[p]);
  @*/
diana_status diana_transpose_substitution(const double *l, size_t n,
                                          const double *b, double *x) {
  double s;
  double r;
  size_t i;
  size_t j;
  size_t k;

  if (l == (const double *)0 || b == (const double *)0 || x == (double *)0 ||
      n == 0u || n > (size_t)-1 / n) {
    return DIANA_ERR_ARG;
  }

  /*@ assert n * n <= 18446744073709551615; */

  /*@ loop invariant 0 <= j <= n;
    @ loop assigns j, i;
    @ loop variant n - j;
    @*/
  for (j = 0u; j < n; ++j) {
    /*@ assert 0 <= n * (n - 1 - j); */
    /*@ loop invariant j <= i <= n;
      @ loop assigns i;
      @ loop variant n - i;
      @*/
    for (i = j; i < n; ++i) {
      if (!diana_fp_finite(l[i + j * n])) {
        return DIANA_ERR_ARG;
      }
    }
  }
  /*@ loop invariant 0 <= i <= n;
    @ loop assigns i;
    @ loop variant n - i;
    @*/
  for (i = 0u; i < n; ++i) {
    if (!diana_fp_finite(b[i])) {
      return DIANA_ERR_ARG;
    }
  }
  /*@ loop invariant 0 <= i <= n;
    @ loop assigns i;
    @ loop variant n - i;
    @*/
  for (i = 0u; i < n; ++i) {
    /*@ assert 0 <= n * (n - 1 - i); */
    if (l[i + i * n] == 0.0) {
      return DIANA_ERR_SINGULAR;
    }
  }

  i = n;
  /*@ loop invariant 0 <= i <= n;
    @ loop invariant \forall integer p; i <= p < n ==> \is_finite(x[p]);
    @ loop assigns i, k, s, r, x[0 .. n - 1];
    @ loop variant i;
    @*/
  while (i > 0u) {
    --i;
    /*@ assert 0 <= n * (n - 1 - i); */
    s = b[i];
    /*@ loop invariant i <= k <= n - 1;
      @ loop assigns k, s;
      @ loop variant k;
      @*/
    for (k = n - 1u; k > i; --k) {
      s = s - l[k + i * n] * x[k];
    }
    r = s / l[i + i * n];
    if (!diana_fp_finite(r)) {
      return DIANA_ERR_OVERFLOW;
    }
    x[i] = r;
  }
  return DIANA_OK;
}
