#include "bisection_acsl.h"
#include "bisection_mid.h"
#include "diana/bisection.h"
#include "fp.h"

/*@ requires s == \null || \valid(s);
  @ assigns *s;
  @ ensures \result == DIANA_ERR_ARG || \result == DIANA_ERR_BRACKET ||
  @         \result == DIANA_OK || \result == DIANA_CONTINUE;
  @ ensures (\result == DIANA_OK || \result == DIANA_CONTINUE) ==> bisection_bracket(s, DIANA_BISECTION_MAX_ACSL);
  @ ensures \result == DIANA_CONTINUE ==> bisection_next(s);
  @ ensures (\result == DIANA_OK || \result == DIANA_CONTINUE) ==> s->status == \result;
  @ ensures (\result == DIANA_ERR_ARG || \result == DIANA_ERR_BRACKET) && s != \null ==>
  @         bisection_unchanged{Pre, Post}(s);
  @*/
diana_status diana_bisection_init(diana_bisection_state *s, double a, double b,
                                  double fa, double fb, double tol,
                                  unsigned max_iter) {
  if (s == (diana_bisection_state *)0) {
    return DIANA_ERR_ARG;
  }
  if (!diana_fp_finite(a) || !diana_fp_finite(b) || !diana_fp_finite(fa) ||
      !diana_fp_finite(fb) || !diana_fp_finite(tol)) {
    return DIANA_ERR_ARG;
  }
  if (a > b || tol < 0.0 || max_iter == 0u) {
    return DIANA_ERR_ARG;
  }
  if (diana_fp_abs(a) > DIANA_BISECTION_MAX ||
      diana_fp_abs(b) > DIANA_BISECTION_MAX) {
    return DIANA_ERR_ARG;
  }
  if ((fa > 0.0 && fb > 0.0) || (fa < 0.0 && fb < 0.0)) {
    return DIANA_ERR_BRACKET;
  }

  s->a = a;
  s->b = b;
  s->fa = fa;
  s->fb = fb;
  s->tol = tol;
  s->iter = 0u;
  s->max_iter = max_iter;
  s->x = diana_bisection_mid(a, b);

  if (fa == 0.0) {
    s->b = a;
    s->fb = fa;
    s->x = a;
    s->status = DIANA_OK;
    return DIANA_OK;
  }
  if (fb == 0.0) {
    s->a = b;
    s->fa = fb;
    s->x = b;
    s->status = DIANA_OK;
    return DIANA_OK;
  }
  if (b - a <= tol || s->x <= a || s->x >= b) {
    s->status = DIANA_OK;
    return DIANA_OK;
  }
  s->status = DIANA_CONTINUE;
  return DIANA_CONTINUE;
}
