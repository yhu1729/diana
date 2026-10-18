#include <stddef.h>

#include "diana/euler.h"

diana_status diana_euler(diana_ode_fn fn, void *ctx, double t0, double h,
                         unsigned nstep, double *y, size_t d, double *work,
                         size_t lwork, unsigned *done) {
  double *next;
  diana_status st;
  unsigned k;
  size_t i;

  if (done != (unsigned *)0) {
    *done = 0u;
  }
  if (fn == (diana_ode_fn)0 || y == (double *)0 || work == (double *)0 ||
      d == 0u || lwork / 2u < d) {
    return DIANA_ERR_ARG;
  }

  next = work + d;
  for (k = 0u; k < nstep; ++k) {
    if (fn(t0 + (double)k * h, y, work, d, ctx) != 0) {
      return DIANA_ERR_CALLBACK;
    }
    st = diana_euler_step(y, work, d, h, next);
    if (st != DIANA_OK) {
      return st;
    }
    for (i = 0u; i < d; ++i) {
      y[i] = next[i];
    }
    if (done != (unsigned *)0) {
      *done = k + 1u;
    }
  }
  return DIANA_OK;
}
