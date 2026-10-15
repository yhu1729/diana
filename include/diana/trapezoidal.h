#ifndef DIANA_TRAPEZOIDAL_H
#define DIANA_TRAPEZOIDAL_H

#include <stddef.h>

#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

diana_status diana_trapezoidal(const double *y, size_t n, double h,
                               double *result);

#ifdef __cplusplus
}
#endif

#endif
