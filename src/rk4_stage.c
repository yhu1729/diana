#include <stddef.h>

#include "diana/rk4.h"
#include "fp.h"

/*@ requires y == \null || k == \null || y_out == \null || d == 0 ||
  @          stage < 2 || stage > 4 ||
  @          (\valid_read(y + (0 .. d - 1)) && \valid_read(k + (0 .. d - 1)) &&
  @           \valid(y_out + (0 .. d - 1)) &&
  @           \separated(y_out + (0 .. d - 1), y + (0 .. d - 1)) &&
  @           \separated(y_out + (0 .. d - 1), k + (0 .. d - 1)));
  @ assigns y_out[0 .. d - 1];
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_ARG ||
  @         \result == DIANA_ERR_OVERFLOW;
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_OVERFLOW ==>
  @         y != \null && k != \null && y_out != \null && d >= 1 &&
  @         2 <= stage <= 4;
  @ ensures \result == DIANA_ERR_OVERFLOW ==>
  @         \is_finite(h) &&
  @         \forall integer j; 0 <= j < d ==> \is_finite(y[j]) && \is_finite(k[j]);
  @ ensures (\result == DIANA_ERR_ARG || \result == DIANA_ERR_OVERFLOW) && y_out != \null ==>
  @         \forall integer j; 0 <= j < d ==> y_out[j] == \old(y_out[j]);
  @*/
diana_status diana_rk4_stage(const double *y, const double *k, size_t d,
                             double h, int stage, double *y_out) {
  double c;
  double r;
  size_t i;
  size_t j;

  if (y == (const double *)0 || k == (const double *)0 ||
      y_out == (double *)0 || d == 0u || stage < 2 || stage > 4) {
    return DIANA_ERR_ARG;
  }

  if (stage == 4) {
    c = h;
  } else {
    c = 0.5 * h;
  }

  /*@ loop invariant 0 <= i <= d;
    @ loop assigns i, j, r;
    @ loop variant d - i;
    @*/
  for (i = 0u; i < d; ++i) {
    r = y[i] + c * k[i];
    if (!diana_fp_finite(r)) {
      if (!diana_fp_finite(h)) {
        return DIANA_ERR_ARG;
      }
      /*@ loop invariant 0 <= j <= d;
        @ loop invariant \forall integer p; 0 <= p < j ==>
        @                \is_finite(y[p]) && \is_finite(k[p]);
        @ loop assigns j;
        @ loop variant d - j;
        @*/
      for (j = 0u; j < d; ++j) {
        if (!diana_fp_finite(y[j])) {
          return DIANA_ERR_ARG;
        }
        if (!diana_fp_finite(k[j])) {
          return DIANA_ERR_ARG;
        }
      }
      return DIANA_ERR_OVERFLOW;
    }
  }

  /*@ loop invariant 0 <= i <= d;
    @ loop assigns i, r, y_out[0 .. d - 1];
    @ loop variant d - i;
    @*/
  for (i = 0u; i < d; ++i) {
    r = y[i] + c * k[i];
    y_out[i] = r;
  }
  return DIANA_OK;
}
