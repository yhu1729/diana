#ifndef DIANA_EULER_H
#define DIANA_EULER_H

#include <stddef.h>

#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

diana_status diana_euler_step(const double *y, const double *f, size_t d,
                              double h, double *y_out);

#ifdef __cplusplus
}
#endif

#endif
