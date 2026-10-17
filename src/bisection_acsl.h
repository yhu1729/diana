#ifndef DIANA_BISECTION_ACSL_H
#define DIANA_BISECTION_ACSL_H

#include "diana/bisection.h"

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

#endif
