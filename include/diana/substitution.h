#ifndef DIANA_SUBSTITUTION_H
#define DIANA_SUBSTITUTION_H

#include <stddef.h>

#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

diana_status diana_forward_substitution(const double *l, size_t n,
                                        const double *b, double *x);
diana_status diana_back_substitution(const double *l, size_t n, const double *b,
                                     double *x);

#ifdef __cplusplus
}
#endif

#endif
