#include <stddef.h>

#include "diana/lu_solve.h"
#include "fp.h"

/*@ lemma column_end: \forall integer n, j; 0 <= j < n ==> 0 <= n * (n - 1 - j);
  @*/

/*@ predicate lu_solve_valid(double *lu, size_t *piv, integer n, double *b,
  @                          double *x) =
  @   \valid_read(lu + (0 .. n * n - 1)) && \valid_read(piv + (0 .. n - 1)) &&
  @   \valid_read(b + (0 .. n - 1)) && \valid(x + (0 .. n - 1)) &&
  @   \separated(x + (0 .. n - 1), lu + (0 .. n * n - 1)) &&
  @   \separated(x + (0 .. n - 1), piv + (0 .. n - 1)) &&
  @   \separated(x + (0 .. n - 1), b + (0 .. n - 1));
  @*/

/*@ requires lu == \null || piv == \null || b == \null || x == \null ||
  @          n == 0 || n > 18446744073709551615 / n ||
  @          lu_solve_valid(lu, piv, n, b, x);
  @ assigns x[0 .. n - 1];
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_ARG ||
  @         \result == DIANA_ERR_SINGULAR || \result == DIANA_ERR_OVERFLOW;
  @ ensures \result != DIANA_ERR_ARG ==>
  @         lu != \null && piv != \null && b != \null && x != \null &&
  @         n >= 1 && n * n <= 18446744073709551615;
  @ ensures lu != \null && piv != \null && b != \null && x != \null &&
  @         n >= 1 && n * n <= 18446744073709551615 &&
  @         ((\exists integer w; 0 <= w < n * n && !\is_finite(\old(lu[w]))) ||
  @          (\exists integer w; 0 <= w < n && \old(piv[w]) >= n) ||
  @          (\exists integer w; 0 <= w < n && !\is_finite(\old(b[w])))) ==>
  @         \result == DIANA_ERR_ARG &&
  @         (\forall integer w; 0 <= w < n ==> x[w] == \old(x[w]));
  @ ensures \result == DIANA_ERR_SINGULAR ==>
  @         \forall integer w; 0 <= w < n ==> x[w] == \old(x[w]);
  @ ensures \result == DIANA_OK ==>
  @         \forall integer w; 0 <= w < n ==> \is_finite(x[w]);
  @*/
diana_status diana_lu_solve(const double *lu, const size_t *piv, size_t n,
                            const double *b, double *x) {
  double s;
  double r;
  double t;
  size_t q;
  size_t p;
  size_t i;
  size_t k;

  if (lu == (const double *)0 || piv == (const size_t *)0 ||
      b == (const double *)0 || x == (double *)0 || n == 0u ||
      n > (size_t)-1 / n) {
    return DIANA_ERR_ARG;
  }

  /*@ assert n * n <= 18446744073709551615; */

  /*@ loop invariant 0 <= q <= n * n;
    @ loop invariant \forall integer w; 0 <= w < q ==> \is_finite(lu[w]);
    @ loop assigns q;
    @ loop variant n * n - q;
    @*/
  for (q = 0u; q < n * n; ++q) {
    if (!diana_fp_finite(lu[q])) {
      return DIANA_ERR_ARG;
    }
  }
  /*@ loop invariant 0 <= k <= n;
    @ loop invariant \forall integer w; 0 <= w < k ==> piv[w] < n;
    @ loop assigns k;
    @ loop variant n - k;
    @*/
  for (k = 0u; k < n; ++k) {
    if (piv[k] >= n) {
      return DIANA_ERR_ARG;
    }
  }
  /*@ loop invariant 0 <= i <= n;
    @ loop invariant \forall integer w; 0 <= w < i ==> \is_finite(b[w]);
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
    if (lu[i + i * n] == 0.0) {
      return DIANA_ERR_SINGULAR;
    }
  }

  /*@ loop invariant 0 <= i <= n;
    @ loop assigns i, x[0 .. n - 1];
    @ loop variant n - i;
    @*/
  for (i = 0u; i < n; ++i) {
    x[i] = b[i];
  }
  /*@ loop invariant 0 <= k <= n;
    @ loop assigns k, p, t, x[0 .. n - 1];
    @ loop variant n - k;
    @*/
  for (k = 0u; k < n; ++k) {
    p = piv[k];
    t = x[k];
    x[k] = x[p];
    x[p] = t;
  }
  /*@ loop invariant 0 <= i <= n;
    @ loop assigns i, k, s, x[0 .. n - 1];
    @ loop variant n - i;
    @*/
  for (i = 0u; i < n; ++i) {
    /*@ assert 0 <= n * (n - 1 - i); */
    s = x[i];
    /*@ loop invariant 0 <= k <= i;
      @ loop assigns k, s;
      @ loop variant i - k;
      @*/
    for (k = 0u; k < i; ++k) {
      /*@ assert 0 <= n * (n - 1 - k); */
      s = s - lu[i + k * n] * x[k];
    }
    if (!diana_fp_finite(s)) {
      return DIANA_ERR_OVERFLOW;
    }
    x[i] = s;
  }
  i = n;
  /*@ loop invariant 0 <= i <= n;
    @ loop invariant \forall integer w; i <= w < n ==> \is_finite(x[w]);
    @ loop assigns i, k, s, r, x[0 .. n - 1];
    @ loop variant i;
    @*/
  while (i > 0u) {
    --i;
    /*@ assert 0 <= n * (n - 1 - i); */
    s = x[i];
    /*@ loop invariant i <= k <= n - 1;
      @ loop assigns k, s;
      @ loop variant k;
      @*/
    for (k = n - 1u; k > i; --k) {
      /*@ assert 0 <= n * (n - 1 - k); */
      s = s - lu[i + k * n] * x[k];
    }
    r = s / lu[i + i * n];
    if (!diana_fp_finite(r)) {
      return DIANA_ERR_OVERFLOW;
    }
    x[i] = r;
  }
  return DIANA_OK;
}
