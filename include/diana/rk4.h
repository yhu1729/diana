#ifndef DIANA_RK4_H
#define DIANA_RK4_H

#include <stddef.h>

#include "diana/ode.h"
#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

diana_status diana_rk4_stage(const double *y, const double *k, size_t d,
                             double h, int stage, double *y_out);
diana_status diana_rk4_stage_unchecked(const double *y, const double *k,
                                       size_t d, double h, int stage,
                                       double *y_out);

diana_status diana_rk4_step(const double *y, const double *k1, const double *k2,
                            const double *k3, const double *k4, size_t d,
                            double h, double *y_out);
diana_status diana_rk4_step_unchecked(const double *y, const double *k1,
                                      const double *k2, const double *k3,
                                      const double *k4, size_t d, double h,
                                      double *y_out);

diana_status diana_rk4(diana_ode_fn fn, void *ctx, double t0, double h,
                       unsigned nstep, double *y, size_t d, double *work,
                       unsigned *done);

#ifdef __cplusplus
}
#endif

#endif
