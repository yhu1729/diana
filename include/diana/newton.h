#ifndef DIANA_NEWTON_H
#define DIANA_NEWTON_H

#include "diana/status.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct diana_newton_state {
  double x;
  double dx;
  double tol;
  unsigned iter;
  unsigned max_iter;
  diana_status status;
} diana_newton_state;

diana_status diana_newton_init(diana_newton_state *s, double x0, double tol,
                               unsigned max_iter);

diana_status diana_newton_step(diana_newton_state *s, double fx, double dfx);

diana_status diana_newton_result(const diana_newton_state *s, double *root,
                                 double *dx);

typedef double (*diana_newton_fn)(double x, double *dfx, void *ctx);

diana_status diana_newton(diana_newton_fn f, void *ctx, double x0, double tol,
                          unsigned max_iter, double *root, unsigned *iter);

#ifdef __cplusplus
}
#endif

#endif
