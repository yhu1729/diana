#include "diana/bisection.h"

diana_status diana_bisection(diana_scalar_fn f, void *ctx, double a, double b,
                             double tol, unsigned max_iter, double *root,
                             unsigned *iter) {
  diana_bisection_state s;
  diana_status st;
  double fa, fb;

  if (iter != (unsigned *)0) {
    *iter = 0u;
  }
  if (f == (diana_scalar_fn)0 || root == (double *)0) {
    return DIANA_ERR_ARG;
  }

  fa = f(a, ctx);
  fb = f(b, ctx);
  st = diana_bisection_init(&s, a, b, fa, fb, tol, max_iter);
  if (st != DIANA_OK && st != DIANA_CONTINUE) {
    return st;
  }
  while (st == DIANA_CONTINUE) {
    st = diana_bisection_step(&s, f(s.x, ctx));
  }

  if (iter != (unsigned *)0) {
    *iter = s.iter;
  }
  if (st != DIANA_OK && st != DIANA_ERR_MAXITER) {
    return st;
  }
  (void)diana_bisection_result(&s, root, (double *)0);
  return st;
}
