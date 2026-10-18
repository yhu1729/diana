#ifndef DIANA_LU_H
#define DIANA_LU_H

#include <stddef.h>

#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

diana_status diana_lu(const double *a, size_t n, double *lu, size_t *piv);

#ifdef __cplusplus
}
#endif

#endif
