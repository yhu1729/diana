#ifndef DIANA_RK4_H
#define DIANA_RK4_H

#include <stddef.h>

#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

diana_status diana_rk4_stage(const double *y, const double *k, size_t d,
                             double h, int stage, double *y_out);

diana_status diana_rk4_step(const double *y, const double *k1, const double *k2,
                            const double *k3, const double *k4, size_t d,
                            double h, double *y_out);

#ifdef __cplusplus
}
#endif

#endif
