#ifndef DIANA_WRAPPER_H
#define DIANA_WRAPPER_H

#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef double (*diana_bisection_fn)(double x, void *ctx);

diana_status diana_bisection(diana_bisection_fn f, void *ctx, double a,
                             double b, double tol, unsigned max_iter,
                             double *root, unsigned *iter);

#ifdef __cplusplus
}
#endif

#endif
