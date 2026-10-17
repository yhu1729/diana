#ifndef DIANA_EULER_H
#define DIANA_EULER_H

#include <stddef.h>

#include "diana/ode.h"
#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

diana_status diana_euler_step(const double *y, const double *f, size_t d,
                              double h, double *y_out);
diana_status diana_euler_step_unchecked(const double *y, const double *f,
                                        size_t d, double h, double *y_out);

diana_status diana_euler(diana_ode_fn fn, void *ctx, double t0, double h,
                         unsigned nstep, double *y, size_t d, double *work,
                         unsigned *done);

#ifdef __cplusplus
}
#endif

#endif
