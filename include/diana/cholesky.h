#ifndef DIANA_CHOLESKY_H
#define DIANA_CHOLESKY_H

#include <stddef.h>

#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

diana_status diana_cholesky(const double *a, size_t n, double *l);

#ifdef __cplusplus
}
#endif

#endif
