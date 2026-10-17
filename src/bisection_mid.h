#ifndef DIANA_BISECTION_MID_H
#define DIANA_BISECTION_MID_H

#include <float.h>

#define DIANA_BISECTION_MAX (DBL_MAX / 2.0)
#define DIANA_BISECTION_MAX_ACSL (((1 << 53) - 1) << 970)

/*@ requires \is_finite(a) && \is_finite(b) && a <= b;
  @ requires -DIANA_BISECTION_MAX_ACSL <= a && b <= DIANA_BISECTION_MAX_ACSL;
  @ terminates \true;
  @ assigns \nothing;
  @ ensures \is_finite(\result) && a <= \result <= b;
  @ exits \false;
  @*/
double diana_bisection_mid(double a, double b);

#endif
