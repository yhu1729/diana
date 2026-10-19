#ifndef DIANA_NORM_H
#define DIANA_NORM_H

#include <stddef.h>

#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

diana_status diana_norm_1(const double *x, size_t n, double *result);
diana_status diana_norm_2(const double *x, size_t n, double *result);
diana_status diana_norm_inf(const double *x, size_t n, double *result);

#ifdef __cplusplus
}
#endif

#endif
