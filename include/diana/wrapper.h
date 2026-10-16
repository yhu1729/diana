#ifndef DIANA_WRAPPER_H
#define DIANA_WRAPPER_H

#include <stddef.h>

#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef double (*diana_bisection_fn)(double x, void *ctx);

diana_status diana_bisection(diana_bisection_fn f, void *ctx, double a,
                             double b, double tol, unsigned max_iter,
                             double *root, unsigned *iter);

typedef void (*diana_ode_fn)(double t, const double *y, double *dy, size_t d,
                             void *ctx);

diana_status diana_euler(diana_ode_fn fn, void *ctx, double t0, double h,
                         unsigned nstep, double *y, size_t d, double *work,
                         unsigned *done);

#ifdef __cplusplus
}
#endif

#endif
