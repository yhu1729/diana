#ifndef DIANA_LU_SOLVE_H
#define DIANA_LU_SOLVE_H

#include <stddef.h>

#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

diana_status diana_lu_solve(const double *lu, const size_t *piv, size_t n,
                            const double *b, double *x);

#ifdef __cplusplus
}
#endif

#endif
