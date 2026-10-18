#include <stddef.h>

#include "diana/rk4.h"
#include "fp.h"

/*@ requires y == \null || k1 == \null || k2 == \null || k3 == \null ||
  @          k4 == \null || y_out == \null || d == 0 ||
  @          (\valid_read(y + (0 .. d - 1)) && \valid_read(k1 + (0 .. d - 1)) &&
  @           \valid_read(k2 + (0 .. d - 1)) &&
  @           \valid_read(k3 + (0 .. d - 1)) &&
  @           \valid_read(k4 + (0 .. d - 1)) && \valid(y_out + (0 .. d - 1)) &&
  @           \separated(y_out + (0 .. d - 1), y + (0 .. d - 1)) &&
  @           \separated(y_out + (0 .. d - 1), k1 + (0 .. d - 1)) &&
  @           \separated(y_out + (0 .. d - 1), k2 + (0 .. d - 1)) &&
  @           \separated(y_out + (0 .. d - 1), k3 + (0 .. d - 1)) &&
  @           \separated(y_out + (0 .. d - 1), k4 + (0 .. d - 1)));
  @ assigns y_out[0 .. d - 1];
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_ARG ||
  @         \result == DIANA_ERR_OVERFLOW;
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_OVERFLOW ==>
  @         y != \null && k1 != \null && k2 != \null && k3 != \null &&
  @         k4 != \null && y_out != \null && d >= 1;
  @ ensures \result == DIANA_ERR_OVERFLOW ==>
  @         \is_finite(h) &&
  @         \forall integer j; 0 <= j < d ==>
  @           \is_finite(y[j]) && \is_finite(k1[j]) && \is_finite(k2[j]) &&
  @           \is_finite(k3[j]) && \is_finite(k4[j]);
  @ ensures (\result == DIANA_ERR_ARG || \result == DIANA_ERR_OVERFLOW) && y_out != \null ==>
  @         \forall integer j; 0 <= j < d ==> y_out[j] == \old(y_out[j]);
  @*/
diana_status diana_rk4_step(const double *y, const double *k1, const double *k2,
                            const double *k3, const double *k4, size_t d,
                            double h, double *y_out) {
  double s;
  double r;
  size_t i;
  size_t j;

  if (y == (const double *)0 || k1 == (const double *)0 ||
      k2 == (const double *)0 || k3 == (const double *)0 ||
      k4 == (const double *)0 || y_out == (double *)0 || d == 0u) {
    return DIANA_ERR_ARG;
  }

  /*@ loop invariant 0 <= i <= d;
    @ loop assigns i, j, s, r;
    @ loop variant d - i;
    @*/
  for (i = 0u; i < d; ++i) {
    s = (k1[i] + k4[i]) + 2.0 * (k2[i] + k3[i]);
    r = y[i] + h * s / 6.0;
    if (!diana_fp_finite(r)) {
      if (!diana_fp_finite(h)) {
        return DIANA_ERR_ARG;
      }
      /*@ loop invariant 0 <= j <= d;
        @ loop invariant \forall integer p; 0 <= p < j ==> \is_finite(y[p]);
        @ loop invariant \forall integer p; 0 <= p < j ==> \is_finite(k1[p]);
        @ loop invariant \forall integer p; 0 <= p < j ==> \is_finite(k2[p]);
        @ loop invariant \forall integer p; 0 <= p < j ==> \is_finite(k3[p]);
        @ loop invariant \forall integer p; 0 <= p < j ==> \is_finite(k4[p]);
        @ loop assigns j;
        @ loop variant d - j;
        @*/
      for (j = 0u; j < d; ++j) {
        if (!diana_fp_finite(y[j])) {
          return DIANA_ERR_ARG;
        }
        if (!diana_fp_finite(k1[j])) {
          return DIANA_ERR_ARG;
        }
        if (!diana_fp_finite(k2[j])) {
          return DIANA_ERR_ARG;
        }
        if (!diana_fp_finite(k3[j])) {
          return DIANA_ERR_ARG;
        }
        if (!diana_fp_finite(k4[j])) {
          return DIANA_ERR_ARG;
        }
      }
      return DIANA_ERR_OVERFLOW;
    }
  }

  /*@ loop invariant 0 <= i <= d;
    @ loop assigns i, s, r, y_out[0 .. d - 1];
    @ loop variant d - i;
    @*/
  for (i = 0u; i < d; ++i) {
    s = (k1[i] + k4[i]) + 2.0 * (k2[i] + k3[i]);
    r = y[i] + h * s / 6.0;
    y_out[i] = r;
  }
  return DIANA_OK;
}
