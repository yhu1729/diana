#include <float.h>

#include "diana/bisection.h"
#include "fp.h"

#define DIANA_BISECTION_MAX (DBL_MAX / 2.0)
#define DIANA_BISECTION_MAX_ACSL (((1 << 53) - 1) << 970)

/*@ requires \is_finite(a) && \is_finite(b) && a <= b;
  @ requires -DIANA_BISECTION_MAX_ACSL <= a && b <= DIANA_BISECTION_MAX_ACSL;
  @ assigns \nothing;
  @ ensures \is_finite(\result) && a <= \result <= b;
  @*/
static double bisection_mid(double a, double b) { return 0.5 * (a + b); }

/*@ predicate bisection_next(diana_bisection_state *s) =
  @   \is_finite(s->x) && s->a < s->x < s->b;
  @*/

/*@ predicate bisection_bracket(diana_bisection_state *s, real m) =
  @   \valid(s) &&
  @   \is_finite(s->a) && \is_finite(s->b) && \is_finite(s->fa) && \is_finite(s->fb) &&
  @   s->a <= s->b &&
  @   -m <= s->a && s->b <= m &&
  @   ((s->fa < 0. && s->fb > 0.) || (s->fa > 0. && s->fb < 0.) ||
  @    (s->a == s->b && s->fa == 0. && s->fb == 0.)) &&
  @   s->tol >= 0.;
  @*/

/*@ predicate bisection_unchanged{L1, L2}(diana_bisection_state *s) =
  @   \at(s->a, L1) == \at(s->a, L2) && \at(s->b, L1) == \at(s->b, L2) &&
  @   \at(s->fa, L1) == \at(s->fa, L2) && \at(s->fb, L1) == \at(s->fb, L2) &&
  @   \at(s->x, L1) == \at(s->x, L2) && \at(s->tol, L1) == \at(s->tol, L2) &&
  @   \at(s->iter, L1) == \at(s->iter, L2) &&
  @   \at(s->max_iter, L1) == \at(s->max_iter, L2);
  @*/

/*@ requires s == \null || \valid(s);
  @ assigns *s;
  @ ensures \result == DIANA_ERR_ARG || \result == DIANA_ERR_BRACKET ||
  @         \result == DIANA_OK || \result == DIANA_CONTINUE;
  @ ensures (\result == DIANA_OK || \result == DIANA_CONTINUE) ==> bisection_bracket(s, DIANA_BISECTION_MAX_ACSL);
  @ ensures \result == DIANA_CONTINUE ==> bisection_next(s);
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
  s->x = bisection_mid(a, b);

  if (fa == 0.0) {
    s->b = a;
    s->fb = fa;
    s->x = a;
    return DIANA_OK;
  }
  if (fb == 0.0) {
    s->a = b;
    s->fa = fb;
    s->x = b;
    return DIANA_OK;
  }
  if (b - a <= tol || s->x <= a || s->x >= b) {
    return DIANA_OK;
  }
  return DIANA_CONTINUE;
}

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
  s->x = bisection_mid(s->a, s->b);
  if (s->x <= s->a || s->x >= s->b) {
    return DIANA_OK;
  }
  if (s->iter >= s->max_iter) {
    return DIANA_ERR_MAXITER;
  }
  return DIANA_CONTINUE;
}

/*@ requires s == \null || bisection_bracket(s, DIANA_BISECTION_MAX_ACSL);
  @ requires root == \null || (\valid(root) && \separated(s, root));
  @ requires width == \null || (\valid(width) && \separated(s, width));
  @ requires root == \null || width == \null || \separated(root, width);
  @ assigns *root, *width;
  @ ensures \result == DIANA_ERR_ARG || \result == DIANA_OK;
  @ ensures \result == DIANA_OK && root != \null ==> s->a <= *root <= s->b;
  @ ensures \result == DIANA_OK && width != \null ==> *width == (double)(s->b - s->a);
  @*/
diana_status diana_bisection_result(const diana_bisection_state *s,
                                    double *root, double *width) {
  if (s == (const diana_bisection_state *)0) {
    return DIANA_ERR_ARG;
  }
  if (root != (double *)0) {
    *root = bisection_mid(s->a, s->b);
  }
  if (width != (double *)0) {
    *width = s->b - s->a;
  }
  return DIANA_OK;
}
