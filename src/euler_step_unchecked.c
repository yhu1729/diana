#include <stddef.h>

#include "diana/euler.h"

/*@ requires y == \null || f == \null || y_out == \null || d == 0 ||
  @          (\valid_read(y + (0 .. d - 1)) && \valid_read(f + (0 .. d - 1)) &&
  @           \valid(y_out + (0 .. d - 1)) &&
  @           \separated(y_out + (0 .. d - 1), y + (0 .. d - 1)) &&
  @           \separated(y_out + (0 .. d - 1), f + (0 .. d - 1)));
  @ assigns y_out[0 .. d - 1];
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_ARG;
  @ ensures \result == DIANA_OK <==>
  @         y != \null && f != \null && y_out != \null && d >= 1;
  @ ensures \result == DIANA_ERR_ARG && y_out != \null ==>
  @         \forall integer j; 0 <= j < d ==> y_out[j] == \old(y_out[j]);
  @*/
diana_status diana_euler_step_unchecked(const double *y, const double *f,
                                        size_t d, double h, double *y_out) {
  size_t i;

  if (y == (const double *)0 || f == (const double *)0 ||
      y_out == (double *)0 || d == 0u) {
    return DIANA_ERR_ARG;
  }

  /*@ loop invariant 0 <= i <= d;
    @ loop assigns i, y_out[0 .. d - 1];
    @ loop variant d - i;
    @*/
  for (i = 0u; i < d; ++i) {
    y_out[i] = y[i] + h * f[i];
  }
  return DIANA_OK;
}
