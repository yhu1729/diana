#include "diana/newton.h"
#include "fp.h"
#include "newton_acsl.h"

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
