#ifndef DIANA_BISECT_H
#define DIANA_BISECT_H

#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct diana_bisect_state {
  double a;
  double b;
  double fa;
  double fb;
  double x;
  double tol;
  unsigned iter;
  unsigned max_iter;
} diana_bisect_state;

diana_status diana_bisect_init(diana_bisect_state *s, double a, double b,
                               double fa, double fb, double tol,
                               unsigned max_iter);

diana_status diana_bisect_step(diana_bisect_state *s, double fx);

diana_status diana_bisect_result(const diana_bisect_state *s, double *root,
                                 double *width);

#ifdef __cplusplus
}
#endif

#endif
