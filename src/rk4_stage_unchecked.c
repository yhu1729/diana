#include <stddef.h>

#include "diana/rk4.h"

/*@ requires y == \null || k == \null || y_out == \null || d == 0 ||
  @          stage < 2 || stage > 4 ||
  @          (\valid_read(y + (0 .. d - 1)) && \valid_read(k + (0 .. d - 1)) &&
  @           \valid(y_out + (0 .. d - 1)) &&
  @           \separated(y_out + (0 .. d - 1), y + (0 .. d - 1)) &&
  @           \separated(y_out + (0 .. d - 1), k + (0 .. d - 1)));
  @ assigns y_out[0 .. d - 1];
  @ ensures \result == DIANA_OK || \result == DIANA_ERR_ARG;
  @ ensures \result == DIANA_OK <==>
  @         y != \null && k != \null && y_out != \null && d >= 1 &&
  @         2 <= stage <= 4;
  @ ensures \result == DIANA_ERR_ARG && y_out != \null ==>
  @         \forall integer j; 0 <= j < d ==> y_out[j] == \old(y_out[j]);
  @*/
diana_status diana_rk4_stage_unchecked(const double *y, const double *k,
                                       size_t d, double h, int stage,
                                       double *y_out) {
  double c;
  size_t i;

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
    @ loop assigns i, y_out[0 .. d - 1];
    @ loop variant d - i;
    @*/
  for (i = 0u; i < d; ++i) {
    y_out[i] = y[i] + c * k[i];
  }
  return DIANA_OK;
}
