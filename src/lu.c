#include <stddef.h>

#include "diana/lu.h"
#include "fp.h"

/*@ lemma column_end: \forall integer n, j; 0 <= j < n ==> 0 <= n * (n - 1 - j);
  @*/

/*@ predicate lu_valid(double *a, integer n, double *lu, size_t *piv) =
  @   \valid_read(a + (0 .. n * n - 1)) && \valid(lu + (0 .. n * n - 1)) &&
  @   \valid(piv + (0 .. n - 1)) &&
  @   \separated(lu + (0 .. n * n - 1), a + (0 .. n * n - 1)) &&
  @   \separated(piv + (0 .. n - 1), a + (0 .. n * n - 1)) &&
  @   \separated(piv + (0 .. n - 1), lu + (0 .. n * n - 1));
  @*/

/*@ requires a == \null || lu == \null || piv == \null || n == 0 ||
  @          n > 18446744073709551615 / n || lu_valid(a, n, lu, piv);
  @ assigns lu[0 .. n * n - 1], piv[0 .. n - 1];
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_ARG ||
  @         \result == DIANA_ERR_SINGULAR;
  @ ensures \result != DIANA_ERR_ARG ==>
  @         a != \null && lu != \null && piv != \null && n >= 1 &&
  @         n * n <= 18446744073709551615;
  @ ensures a != \null && lu != \null && piv != \null && n >= 1 &&
  @         n * n <= 18446744073709551615 &&
  @         (\exists integer w; 0 <= w < n * n && !\is_finite(\old(a[w]))) ==>
  @         \result == DIANA_ERR_ARG &&
  @         (\forall integer w; 0 <= w < n * n ==> lu[w] == \old(lu[w])) &&
  @         (\forall integer w; 0 <= w < n ==> piv[w] == \old(piv[w]));
  @ ensures \result == DIANA_OK ==>
  @         \forall integer w; 0 <= w < n ==> w <= piv[w] < n;
  @*/
diana_status diana_lu(const double *a, size_t n, double *lu, size_t *piv) {
  double m;
  double v;
  double d;
  double u;
  double t;
  size_t q;
  size_t p;
  size_t i;
  size_t j;
  size_t k;

  if (a == (const double *)0 || lu == (double *)0 || piv == (size_t *)0 ||
      n == 0u || n > (size_t)-1 / n) {
    return DIANA_ERR_ARG;
  }

  /*@ assert n * n <= 18446744073709551615; */

  /*@ loop invariant 0 <= q <= n * n;
    @ loop invariant \forall integer w; 0 <= w < q ==> \is_finite(a[w]);
    @ loop assigns q;
    @ loop variant n * n - q;
    @*/
  for (q = 0u; q < n * n; ++q) {
    if (!diana_fp_finite(a[q])) {
      return DIANA_ERR_ARG;
    }
  }
  /*@ loop invariant 0 <= q <= n * n;
    @ loop assigns q, lu[0 .. n * n - 1];
    @ loop variant n * n - q;
    @*/
  for (q = 0u; q < n * n; ++q) {
    lu[q] = a[q];
  }

  /*@ loop invariant 0 <= k <= n;
    @ loop invariant \forall integer w; 0 <= w < k ==> w <= piv[w] < n;
    @ loop assigns k, i, j, p, m, v, d, u, t, lu[0 .. n * n - 1],
    @              piv[0 .. n - 1];
    @ loop variant n - k;
    @*/
  for (k = 0u; k < n; ++k) {
    /*@ assert 0 <= n * (n - 1 - k); */
    p = k;
    m = 0.0;
    /*@ loop invariant k <= i <= n;
      @ loop invariant k <= p < n;
      @ loop assigns i, p, m, v;
      @ loop variant n - i;
      @*/
    for (i = k; i < n; ++i) {
      v = lu[i + k * n];
      if (v < 0.0) {
        v = -v;
      }
      if (v > m) {
        p = i;
        m = v;
      }
    }
    if (m == 0.0) {
      return DIANA_ERR_SINGULAR;
    }
    piv[k] = p;
    /*@ loop invariant 0 <= j <= n;
      @ loop assigns j, t, lu[0 .. n * n - 1];
      @ loop variant n - j;
      @*/
    for (j = 0u; j < n; ++j) {
      /*@ assert 0 <= n * (n - 1 - j); */
      t = lu[k + j * n];
      lu[k + j * n] = lu[p + j * n];
      lu[p + j * n] = t;
    }
    d = lu[k + k * n];
    /*@ loop invariant k + 1 <= i <= n;
      @ loop assigns i, lu[0 .. n * n - 1];
      @ loop variant n - i;
      @*/
    for (i = k + 1u; i < n; ++i) {
      lu[i + k * n] = lu[i + k * n] / d;
    }
    /*@ loop invariant k + 1 <= j <= n;
      @ loop assigns j, i, u, t, lu[0 .. n * n - 1];
      @ loop variant n - j;
      @*/
    for (j = k + 1u; j < n; ++j) {
      /*@ assert 0 <= n * (n - 1 - j); */
      u = lu[k + j * n];
      /*@ loop invariant k + 1 <= i <= n;
        @ loop assigns i, t, lu[0 .. n * n - 1];
        @ loop variant n - i;
        @*/
      for (i = k + 1u; i < n; ++i) {
        t = lu[i + j * n] - lu[i + k * n] * u;
        if (!diana_fp_finite(t)) {
          return DIANA_ERR_ARG;
        }
        lu[i + j * n] = t;
      }
    }
  }
  return DIANA_OK;
}
