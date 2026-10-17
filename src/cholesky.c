#include <stddef.h>

#include "diana/cholesky.h"
#include "fp.h"
#include "fp_sqrt.h"

/*@ lemma column_end: \forall integer n, j; 0 <= j < n ==> 0 <= n * (n - 1 - j);
  @*/

/*@ requires a == \null || l == \null || n == 0 ||
  @          n > 18446744073709551615 / n ||
  @          (\valid_read(a + (0 .. n * n - 1)) && \valid(l + (0 .. n * n - 1)) &&
  @           \separated(l + (0 .. n * n - 1), a + (0 .. n * n - 1)));
  @ assigns l[0 .. n * n - 1];
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_ARG ||
  @         \result == DIANA_ERR_SINGULAR;
  @ ensures \result != DIANA_ERR_ARG ==>
  @         a != \null && l != \null && n >= 1 && n * n <= 18446744073709551615;
  @ ensures \result == DIANA_ERR_ARG && l != \null ==>
  @         \forall integer p; 0 <= p < n * n ==> l[p] == \old(l[p]);
  @*/
diana_status diana_cholesky(const double *a, size_t n, double *l) {
  double s;
  double d;
  size_t i;
  size_t j;
  size_t k;

  if (a == (const double *)0 || l == (double *)0 || n == 0u ||
      n > (size_t)-1 / n) {
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
      if (!diana_fp_finite(a[i + j * n])) {
        return DIANA_ERR_ARG;
      }
    }
  }

  /*@ loop invariant 0 <= j <= n;
    @ loop assigns j, i, k, s, d, l[0 .. n * n - 1];
    @ loop variant n - j;
    @*/
  for (j = 0u; j < n; ++j) {
    /*@ assert 0 <= n * (n - 1 - j); */
    /*@ loop invariant 0 <= i <= j;
      @ loop assigns i, l[0 .. n * n - 1];
      @ loop variant j - i;
      @*/
    for (i = 0u; i < j; ++i) {
      l[i + j * n] = 0.0;
    }
    s = a[j + j * n];
    /*@ loop invariant 0 <= k <= j;
      @ loop assigns k, s;
      @ loop variant j - k;
      @*/
    for (k = 0u; k < j; ++k) {
      /*@ assert 0 <= n * (n - 1 - k); */
      s = s - l[j + k * n] * l[j + k * n];
    }
    if (!(s > 0.0)) {
      return DIANA_ERR_SINGULAR;
    }
    d = diana_fp_sqrt(s);
    l[j + j * n] = d;
    /*@ loop invariant j + 1 <= i <= n;
      @ loop assigns i, k, s, l[0 .. n * n - 1];
      @ loop variant n - i;
      @*/
    for (i = j + 1u; i < n; ++i) {
      s = a[i + j * n];
      /*@ loop invariant 0 <= k <= j;
        @ loop assigns k, s;
        @ loop variant j - k;
        @*/
      for (k = 0u; k < j; ++k) {
        /*@ assert 0 <= n * (n - 1 - k); */
        s = s - l[i + k * n] * l[j + k * n];
      }
      l[i + j * n] = s / d;
    }
  }
  return DIANA_OK;
}
