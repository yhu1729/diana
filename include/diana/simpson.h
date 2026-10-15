#ifndef DIANA_SIMPSON_H
#define DIANA_SIMPSON_H

#include <stddef.h>

#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

diana_status diana_simpson(const double *y, size_t n, double h, double *result);

#ifdef __cplusplus
}
#endif

#endif
