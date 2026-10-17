#include "diana/newton.h"

diana_status diana_newton(diana_newton_fn f, void *ctx, double x0, double tol,
                          unsigned max_iter, double *root, unsigned *iter) {
  diana_newton_state s;
  diana_status st;
  double fx, dfx;

  if (iter != (unsigned *)0) {
    *iter = 0u;
  }
  if (f == (diana_newton_fn)0 || root == (double *)0) {
    return DIANA_ERR_ARG;
  }

  st = diana_newton_init(&s, x0, tol, max_iter);
  if (st != DIANA_CONTINUE) {
    return st;
  }
  while (st == DIANA_CONTINUE) {
    dfx = 0.0;
    fx = f(s.x, &dfx, ctx);
    st = diana_newton_step(&s, fx, dfx);
  }

  if (iter != (unsigned *)0) {
    *iter = s.iter;
  }
  if (st != DIANA_OK && st != DIANA_ERR_MAXITER) {
    return st;
  }
  (void)diana_newton_result(&s, root, (double *)0);
  return st;
}
