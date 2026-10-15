#ifndef DIANA_BISECTION_H
#define DIANA_BISECTION_H

#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct diana_bisection_state {
  double a;
  double b;
  double fa;
  double fb;
  double x;
  double tol;
  unsigned iter;
  unsigned max_iter;
} diana_bisection_state;

diana_status diana_bisection_init(diana_bisection_state *s, double a, double b,
                                  double fa, double fb, double tol,
                                  unsigned max_iter);

diana_status diana_bisection_step(diana_bisection_state *s, double fx);

diana_status diana_bisection_result(const diana_bisection_state *s,
                                    double *root, double *width);

#ifdef __cplusplus
}
#endif

#endif
