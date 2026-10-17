#include "bisection_acsl.h"
#include "bisection_mid.h"
#include "diana/bisection.h"
#include "fp.h"

/*@ requires s == \null || (bisection_bracket(s, DIANA_BISECTION_MAX_ACSL) && bisection_next(s) &&
  @                        s->iter < s->max_iter);
  @ assigns *s;
  @ ensures \result == DIANA_ERR_ARG || \result == DIANA_ERR_MAXITER ||
  @         \result == DIANA_OK || \result == DIANA_CONTINUE;
  @ ensures \result != DIANA_ERR_ARG ==> bisection_bracket(s, DIANA_BISECTION_MAX_ACSL) &&
  @         \old(s->a) <= s->a && s->b <= \old(s->b) && s->iter == \old(s->iter) + 1;
  @ ensures \result == DIANA_CONTINUE ==> bisection_next(s) && s->iter < s->max_iter;
  @ ensures \result == DIANA_ERR_ARG && s != \null ==> bisection_unchanged{Pre, Post}(s);
  @*/
diana_status diana_bisection_step(diana_bisection_state *s, double fx) {
  double x;

  if (s == (diana_bisection_state *)0 || !diana_fp_finite(fx)) {
    return DIANA_ERR_ARG;
  }

  x = s->x;
  s->iter = s->iter + 1u;

  if (fx == 0.0) {
    s->a = x;
    s->b = x;
    s->fa = fx;
    s->fb = fx;
    return DIANA_OK;
  }
  if ((fx > 0.0) == (s->fa > 0.0)) {
    s->a = x;
    s->fa = fx;
  } else {
    s->b = x;
    s->fb = fx;
  }

  if (s->b - s->a <= s->tol) {
    return DIANA_OK;
  }
  s->x = diana_bisection_mid(s->a, s->b);
  if (s->x <= s->a || s->x >= s->b) {
    return DIANA_OK;
  }
  if (s->iter >= s->max_iter) {
    return DIANA_ERR_MAXITER;
  }
  return DIANA_CONTINUE;
}
