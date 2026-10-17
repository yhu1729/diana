#ifndef DIANA_FP_SQRT_H
#define DIANA_FP_SQRT_H

/*@ requires \gt_double(x, (double)0.0);
  @ terminates \true;
  @ assigns \nothing;
  @ ensures \is_finite(x) ==>
  @         \is_finite(\result) && \result > 0.0 && \result == (double)\sqrt(x);
  @ ensures \is_plus_infinity(x) ==> \is_plus_infinity(\result);
  @ exits \false;
  @*/
double diana_fp_sqrt(double x);

#endif
