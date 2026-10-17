#include "diana/newton.h"

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
