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
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_ARG;
  @ ensures \result == DIANA_OK ==>
  @         y != \null && k1 != \null && k2 != \null && k3 != \null &&
  @         k4 != \null && y_out != \null && d >= 1;
  @ ensures \result == DIANA_ERR_ARG && y_out != \null ==>
  @         \forall integer j; 0 <= j < d ==> y_out[j] == \old(y_out[j]);
  @*/
diana_status diana_rk4_step(const double *y, const double *k1, const double *k2,
                            const double *k3, const double *k4, size_t d,
                            double h, double *y_out) {
  double s;
  double r;
  size_t i;

  if (y == (const double *)0 || k1 == (const double *)0 ||
      k2 == (const double *)0 || k3 == (const double *)0 ||
      k4 == (const double *)0 || y_out == (double *)0 || d == 0u) {
    return DIANA_ERR_ARG;
  }

  /*@ loop invariant 0 <= i <= d;
    @ loop assigns i, s, r;
    @ loop variant d - i;
    @*/
  for (i = 0u; i < d; ++i) {
    s = (k1[i] + k4[i]) + 2.0 * (k2[i] + k3[i]);
    r = y[i] + h * s / 6.0;
    if (!diana_fp_finite(r)) {
      return DIANA_ERR_ARG;
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
