#ifndef DIANA_AXPY_H
#define DIANA_AXPY_H

#include <stddef.h>

#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

diana_status diana_axpy(double a, const double *x, size_t n, double *y);

#ifdef __cplusplus
}
#endif

#endif
