#include "bisection_acsl.h"
#include "bisection_mid.h"
#include "diana/bisection.h"

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
    *root = diana_bisection_mid(s->a, s->b);
  }
  if (width != (double *)0) {
    *width = s->b - s->a;
  }
  return DIANA_OK;
}
