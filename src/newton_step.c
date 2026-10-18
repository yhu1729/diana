#include "diana/newton.h"
#include "fp.h"
#include "newton_acsl.h"

/*@ requires s == \null || (\valid(s) && (s->status != DIANA_CONTINUE ||
  @          (newton_state(s) && s->iter < s->max_iter)));
  @ assigns *s;
  @ ensures \result == DIANA_ERR_ARG || \result == DIANA_ERR_SINGULAR ||
  @         \result == DIANA_ERR_OVERFLOW || \result == DIANA_ERR_MAXITER ||
  @         \result == DIANA_OK || \result == DIANA_CONTINUE;
  @ ensures \result != DIANA_ERR_ARG && \result != DIANA_ERR_SINGULAR &&
  @         \result != DIANA_ERR_OVERFLOW ==>
  @         newton_state(s) && s->iter == \old(s->iter) + 1 && s->tol == \old(s->tol) &&
  @         s->max_iter == \old(s->max_iter);
  @ ensures \result == DIANA_OK ==> \abs(s->dx) <= s->tol || s->x == \old(s->x);
  @ ensures \result == DIANA_CONTINUE ==> s->iter < s->max_iter && \abs(s->dx) > s->tol &&
  @         s->x != \old(s->x);
  @ ensures \result == DIANA_ERR_MAXITER ==> s->iter == s->max_iter;
  @ ensures \result == DIANA_OK || \result == DIANA_CONTINUE || \result == DIANA_ERR_MAXITER ==>
  @         \old(s->status) == DIANA_CONTINUE && s->status == \result;
  @ ensures \result == DIANA_ERR_SINGULAR ==> dfx == 0. && fx != 0.;
  @ ensures \result == DIANA_ERR_OVERFLOW ==>
  @         \is_finite(fx) && \is_finite(dfx) && fx != 0. && dfx != 0.;
  @ ensures (\result == DIANA_ERR_ARG || \result == DIANA_ERR_SINGULAR ||
  @          \result == DIANA_ERR_OVERFLOW) && s != \null ==>
  @         newton_unchanged{Pre, Post}(s);
  @*/
diana_status diana_newton_step(diana_newton_state *s, double fx, double dfx) {
  double dx;
  double x;
  int converged;

  if (s == (diana_newton_state *)0 || s->status != DIANA_CONTINUE ||
      !diana_fp_finite(fx) || !diana_fp_finite(dfx)) {
    return DIANA_ERR_ARG;
  }
  if (fx == 0.0) {
    s->dx = 0.0;
    s->iter = s->iter + 1u;
    s->status = DIANA_OK;
    return DIANA_OK;
  }
  if (dfx == 0.0) {
    return DIANA_ERR_SINGULAR;
  }
  dx = fx / dfx;
  if (!diana_fp_finite(dx)) {
    return DIANA_ERR_OVERFLOW;
  }
  x = s->x - dx;
  if (!diana_fp_finite(x)) {
    return DIANA_ERR_OVERFLOW;
  }
  converged = x == s->x || diana_fp_abs(dx) <= s->tol;
  s->iter = s->iter + 1u;
  s->dx = dx;
  s->x = x;
  if (converged) {
    s->status = DIANA_OK;
    return DIANA_OK;
  }
  if (s->iter >= s->max_iter) {
    s->status = DIANA_ERR_MAXITER;
    return DIANA_ERR_MAXITER;
  }
  return DIANA_CONTINUE;
}
