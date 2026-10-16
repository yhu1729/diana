#include "diana/newton.h"
#include "fp.h"

/*@ predicate newton_state(diana_newton_state *s) =
  @   \valid(s) && \is_finite(s->x) && \is_finite(s->dx) && \is_finite(s->tol) &&
  @   s->tol >= 0.;
  @*/

/*@ predicate newton_unchanged{L1, L2}(diana_newton_state *s) =
  @   \at(s->x, L1) == \at(s->x, L2) && \at(s->dx, L1) == \at(s->dx, L2) &&
  @   \at(s->tol, L1) == \at(s->tol, L2) && \at(s->iter, L1) == \at(s->iter, L2) &&
  @   \at(s->max_iter, L1) == \at(s->max_iter, L2);
  @*/

/*@ requires s == \null || \valid(s);
  @ assigns *s;
  @ ensures \result == DIANA_ERR_ARG || \result == DIANA_CONTINUE;
  @ ensures \result == DIANA_CONTINUE ==> newton_state(s) && s->x == x0 && s->dx == 0. &&
  @         s->tol == tol && s->iter == 0 && s->max_iter == max_iter && max_iter > 0;
  @ ensures \result == DIANA_ERR_ARG && s != \null ==> newton_unchanged{Pre, Post}(s);
  @*/
diana_status diana_newton_init(diana_newton_state *s, double x0, double tol,
                               unsigned max_iter) {
  if (s == (diana_newton_state *)0) {
    return DIANA_ERR_ARG;
  }
  if (!diana_fp_finite(x0) || !diana_fp_finite(tol)) {
    return DIANA_ERR_ARG;
  }
  if (tol < 0.0 || max_iter == 0u) {
    return DIANA_ERR_ARG;
  }
  s->x = x0;
  s->dx = 0.0;
  s->tol = tol;
  s->iter = 0u;
  s->max_iter = max_iter;
  return DIANA_CONTINUE;
}

/*@ requires s == \null || (newton_state(s) && s->iter < s->max_iter);
  @ assigns *s;
  @ ensures \result == DIANA_ERR_ARG || \result == DIANA_ERR_MAXITER ||
  @         \result == DIANA_OK || \result == DIANA_CONTINUE;
  @ ensures \result != DIANA_ERR_ARG ==> newton_state(s) && s->iter == \old(s->iter) + 1 &&
  @         s->tol == \old(s->tol) && s->max_iter == \old(s->max_iter);
  @ ensures \result == DIANA_OK ==> \abs(s->dx) <= s->tol || s->x == \old(s->x);
  @ ensures \result == DIANA_CONTINUE ==> s->iter < s->max_iter && \abs(s->dx) > s->tol &&
  @         s->x != \old(s->x);
  @ ensures \result == DIANA_ERR_MAXITER ==> s->iter == s->max_iter;
  @ ensures \result == DIANA_ERR_ARG && s != \null ==> newton_unchanged{Pre, Post}(s);
  @*/
diana_status diana_newton_step(diana_newton_state *s, double fx, double dfx) {
  double dx;
  double x;
  int converged;

  if (s == (diana_newton_state *)0 || !diana_fp_finite(fx) ||
      !diana_fp_finite(dfx)) {
    return DIANA_ERR_ARG;
  }
  if (fx == 0.0) {
    s->dx = 0.0;
    s->iter = s->iter + 1u;
    return DIANA_OK;
  }
  dx = fx / dfx;
  if (!diana_fp_finite(dx)) {
    return DIANA_ERR_ARG;
  }
  x = s->x - dx;
  if (!diana_fp_finite(x)) {
    return DIANA_ERR_ARG;
  }
  converged = x == s->x || diana_fp_abs(dx) <= s->tol;
  s->iter = s->iter + 1u;
  s->dx = dx;
  s->x = x;
  if (converged) {
    return DIANA_OK;
  }
  if (s->iter >= s->max_iter) {
    return DIANA_ERR_MAXITER;
  }
  return DIANA_CONTINUE;
}

/*@ requires s == \null || \valid_read(s);
  @ requires root == \null || (\valid(root) && \separated(s, root));
  @ requires dx == \null || (\valid(dx) && \separated(s, dx));
  @ requires root == \null || dx == \null || \separated(root, dx);
  @ assigns *root, *dx;
  @ ensures \result == DIANA_ERR_ARG || \result == DIANA_OK;
  @ ensures \result == DIANA_OK && root != \null ==> *root == s->x;
  @ ensures \result == DIANA_OK && dx != \null ==> *dx == s->dx;
  @*/
diana_status diana_newton_result(const diana_newton_state *s, double *root,
                                 double *dx) {
  if (s == (const diana_newton_state *)0) {
    return DIANA_ERR_ARG;
  }
  if (root != (double *)0) {
    *root = s->x;
  }
  if (dx != (double *)0) {
    *dx = s->dx;
  }
  return DIANA_OK;
}
