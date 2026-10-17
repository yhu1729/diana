#include <stddef.h>

#include "diana/rk4.h"

diana_status diana_rk4(diana_ode_fn fn, void *ctx, double t0, double h,
                       unsigned nstep, double *y, size_t d, double *work,
                       unsigned *done) {
  double *k1;
  double *k2;
  double *k3;
  double *k4;
  double *ys;
  diana_status st;
  unsigned k;
  size_t i;

  if (done != (unsigned *)0) {
    *done = 0u;
  }
  if (fn == (diana_ode_fn)0 || y == (double *)0 || work == (double *)0 ||
      d == 0u) {
    return DIANA_ERR_ARG;
  }

  k1 = work;
  k2 = k1 + d;
  k3 = k2 + d;
  k4 = k3 + d;
  ys = k4 + d;
  for (k = 0u; k < nstep; ++k) {
    fn(t0 + (double)k * h, y, k1, d, ctx);
    st = diana_rk4_stage(y, k1, d, h, 2, ys);
    if (st != DIANA_OK) {
      return st;
    }
    fn(t0 + ((double)k + 0.5) * h, ys, k2, d, ctx);
    st = diana_rk4_stage(y, k2, d, h, 3, ys);
    if (st != DIANA_OK) {
      return st;
    }
    fn(t0 + ((double)k + 0.5) * h, ys, k3, d, ctx);
    st = diana_rk4_stage(y, k3, d, h, 4, ys);
    if (st != DIANA_OK) {
      return st;
    }
    fn(t0 + (double)(k + 1u) * h, ys, k4, d, ctx);
    st = diana_rk4_step(y, k1, k2, k3, k4, d, h, ys);
    if (st != DIANA_OK) {
      return st;
    }
    for (i = 0u; i < d; ++i) {
      y[i] = ys[i];
    }
    if (done != (unsigned *)0) {
      *done = k + 1u;
    }
  }
  return DIANA_OK;
}
