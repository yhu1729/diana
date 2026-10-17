#ifndef DIANA_DIANA_H
#define DIANA_DIANA_H

#define DIANA_VERSION_MAJOR 0
#define DIANA_VERSION_MINOR 3
#define DIANA_VERSION_PATCH 0
#define DIANA_VERSION_STRING "0.3.0"

#include "diana/bisection.h"
#include "diana/cholesky.h"
#include "diana/euler.h"
#include "diana/newton.h"
#include "diana/ode.h"
#include "diana/rk4.h"
#include "diana/simpson.h"
#include "diana/status.h"
#include "diana/substitution.h"
#include "diana/trapezoidal.h"

#ifdef __cplusplus
extern "C" {
#endif

const char *diana_version(void);

#ifdef __cplusplus
}
#endif

#endif
