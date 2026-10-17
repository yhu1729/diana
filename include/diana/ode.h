#ifndef DIANA_ODE_H
#define DIANA_ODE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*diana_ode_fn)(double t, const double *y, double *dy, size_t d,
                             void *ctx);

#ifdef __cplusplus
}
#endif

#endif
