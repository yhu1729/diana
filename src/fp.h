#ifndef DIANA_FP_H
#define DIANA_FP_H

/*@ assigns \nothing;
  @ ensures \result == 1 <==> \is_finite(x);
  @ ensures \result == 0 || \result == 1;
  @*/
static inline int diana_fp_finite(double x) { return x == x && (x - x) == 0.0; }

/*@ requires \is_finite(x);
  @ assigns \nothing;
  @ ensures \is_finite(\result) && \result == \abs(x);
  @*/
static inline double diana_fp_abs(double x) { return x < 0.0 ? -x : x; }

#endif
