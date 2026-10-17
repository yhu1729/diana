#ifndef DIANA_SUBSTITUTION_ACSL_H
#define DIANA_SUBSTITUTION_ACSL_H

#include "diana/substitution.h"

/*@ lemma column_end: \forall integer n, j; 0 <= j < n ==> 0 <= n * (n - 1 - j);
  @*/

/*@ predicate substitution_valid(double *l, integer n, double *b, double *x) =
  @   \valid_read(l + (0 .. n * n - 1)) && \valid_read(b + (0 .. n - 1)) &&
  @   \valid(x + (0 .. n - 1)) &&
  @   \separated(x + (0 .. n - 1), l + (0 .. n * n - 1)) &&
  @   \separated(x + (0 .. n - 1), b + (0 .. n - 1));
  @*/

#endif
