#ifndef DIANA_NEWTON_ACSL_H
#define DIANA_NEWTON_ACSL_H

#include "diana/newton.h"

/*@ predicate newton_state(diana_newton_state *s) =
  @   \valid(s) && \is_finite(s->x) && \is_finite(s->dx) && \is_finite(s->tol) &&
  @   s->tol >= 0.;
  @*/

/*@ predicate newton_unchanged{L1, L2}(diana_newton_state *s) =
  @   \at(s->x, L1) == \at(s->x, L2) && \at(s->dx, L1) == \at(s->dx, L2) &&
  @   \at(s->tol, L1) == \at(s->tol, L2) && \at(s->iter, L1) == \at(s->iter, L2) &&
  @   \at(s->max_iter, L1) == \at(s->max_iter, L2) &&
  @   \at(s->status, L1) == \at(s->status, L2);
  @*/

#endif
