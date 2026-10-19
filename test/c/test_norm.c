#include <float.h>
#include <math.h>
#include <stddef.h>

#include "check.h"
#include "diana/diana.h"

#define SENTINEL 42.0

typedef diana_status (*norm_fn)(const double *, size_t, double *);

static const norm_fn norm[3] = {diana_norm_1, diana_norm_2, diana_norm_inf};

static void check_ok(norm_fn f, const double *x, size_t n, double want) {
  double r = SENTINEL;
  CHECK_EQ_STATUS(f(x, n, &r), DIANA_OK);
  CHECK(r == want);
  CHECK(!signbit(r));
}

static void check_fail(norm_fn f, const double *x, size_t n,
                       diana_status want) {
  double r = SENTINEL;
  CHECK_EQ_STATUS(f(x, n, &r), want);
  CHECK(r == SENTINEL);
}

static void test_argument(void) {
  const double x[2] = {1.0, 2.0};
  size_t j;

  for (j = 0; j < 3u; ++j) {
    check_fail(norm[j], (const double *)0, 2u, DIANA_ERR_ARG);
    check_fail(norm[j], (const double *)0, 0u, DIANA_ERR_ARG);
    CHECK_EQ_STATUS(norm[j](x, 2u, (double *)0), DIANA_ERR_ARG);
    CHECK_EQ_STATUS(norm[j]((const double *)0, 2u, (double *)0), DIANA_ERR_ARG);
  }
}

/* The empty vector and every zero vector have norm +0, also with -0
   entries: |-0| is -0 and +0 + -0 is +0, and -0 > +0 is false. */
static void test_zero(void) {
  const double x[3] = {0.0, -0.0, 0.0};
  const double neg[1] = {-0.0};
  size_t j;

  for (j = 0; j < 3u; ++j) {
    check_ok(norm[j], x, 0u, 0.0);
    check_ok(norm[j], x, 3u, 0.0);
    check_ok(norm[j], neg, 1u, 0.0);
  }
}

/* Small integers and the Pythagorean triple (3, 4, 5): every operation is
   exact. In the 2-norm, s = 1 + (3/4)^2 = 1.5625 and sqrt(s) = 1.25. */
static void test_exact(void) {
  const double x[3] = {3.0, -4.0, 1.0};
  const double pair[2] = {-4.0, 3.0};
  const double one[1] = {-7.0};

  check_ok(diana_norm_1, x, 3u, 8.0);
  check_ok(diana_norm_inf, x, 3u, 4.0);
  check_ok(diana_norm_2, x, 2u, 5.0);
  check_ok(diana_norm_2, pair, 2u, 5.0);
  check_ok(diana_norm_1, one, 1u, 7.0);
  check_ok(diana_norm_2, one, 1u, 7.0);
  check_ok(diana_norm_inf, one, 1u, 7.0);
}

/* The 1-norm adds left to right: 2^53 + 1 rounds to 2^53 (ties to even) at
   each step, so the result is 2^53, not the 2^53 + 2 that adding the ones
   first would give. */
static void test_norm_1_order(void) {
  const double p53 = 9007199254740992.0;
  const double x[3] = {p53, 1.0, -1.0};

  check_ok(diana_norm_1, x, 3u, p53);
}

/* The 2-norm starts from the term 1 of the largest entry and adds the others
   in index order: each (2^-27)^2 = 2^-54 is below half an ulp of 1, so s stays
   1 and the result is 1, wherever the 1 is. Adding in index order with the 1
   last would give s = 1 + 2^-50 and a result of 1 + 2^-51. */
static void test_norm_2_order(void) {
  double x[17];
  size_t i;

  for (i = 0; i < 16u; ++i) {
    x[i] = 0x1p-27;
  }
  x[16] = 1.0;
  check_ok(diana_norm_2, x, 17u, 1.0);
  check_ok(diana_norm_2, x + 16, 1u, 1.0);
}

/* Equal largest entries: the first is the scale, the second contributes
   (-4/4)^2 = 1, so the result is 4 * fl(sqrt(2)), an exact product. */
static void test_norm_2_tie(void) {
  const double x[2] = {4.0, -4.0};

  check_ok(diana_norm_2, x, 2u, 4.0 * sqrt(2.0));
}

/* Scaling by the largest entry: no quotient or square overflows, and a
   square that underflows is below the rounding of s >= 1. */
static void test_norm_2_scale(void) {
  const double big[1] = {-DBL_MAX};
  const double big2[2] = {1e300, -1e300};
  const double small2[2] = {1e-200, 1e-200};
  const double tiny[1] = {DBL_TRUE_MIN};
  const double tiny2[2] = {DBL_TRUE_MIN, -DBL_TRUE_MIN};
  const double mixed[2] = {DBL_MAX, DBL_TRUE_MIN};

  check_ok(diana_norm_2, big, 1u, DBL_MAX);
  check_ok(diana_norm_2, big2, 2u, 1e300 * sqrt(2.0));
  check_ok(diana_norm_2, small2, 2u, 1e-200 * sqrt(2.0));
  check_ok(diana_norm_2, tiny, 1u, DBL_TRUE_MIN);
  /* 2^-1074 * 1.414... rounds back to 2^-1074 */
  check_ok(diana_norm_2, tiny2, 2u, DBL_TRUE_MIN);
  /* the quotient 2^-1074 / DBL_MAX underflows to +0 */
  check_ok(diana_norm_2, mixed, 2u, DBL_MAX);
}

static void test_extreme(void) {
  const double x[3] = {DBL_TRUE_MIN, -DBL_MAX, DBL_MIN};
  const double tiny[2] = {DBL_TRUE_MIN, -DBL_TRUE_MIN};

  check_ok(diana_norm_inf, x, 3u, DBL_MAX);
  check_ok(diana_norm_inf, tiny, 2u, DBL_TRUE_MIN);
  check_ok(diana_norm_1, tiny, 2u, 2.0 * DBL_TRUE_MIN);
}

/* Each case has finite entries; only the result overflows. */
static void test_overflow(void) {
  const double pair[2] = {DBL_MAX, -DBL_MAX};
  const double tie[2] = {DBL_MAX, 0x1p970};
  const double below[2] = {DBL_MAX, 0x1p969};
  const double edge[2] = {DBL_MAX, DBL_MAX * 0x1p-26};

  check_fail(diana_norm_1, pair, 2u, DIANA_ERR_OVERFLOW);
  check_fail(diana_norm_2, pair, 2u, DIANA_ERR_OVERFLOW);
  check_ok(diana_norm_inf, pair, 2u, DBL_MAX);
  /* DBL_MAX + 2^970 is halfway to 2^1024 and rounds to even, up */
  check_fail(diana_norm_1, tie, 2u, DIANA_ERR_OVERFLOW);
  check_ok(diana_norm_1, below, 2u, DBL_MAX);
  check_ok(diana_norm_2, tie, 2u, DBL_MAX);
  /* s = 1 + 2^-52 exactly, and sqrt(s) rounds to 1: the result is DBL_MAX,
     though the exact norm DBL_MAX * sqrt(1 + 2^-52) would round to 2^1024 */
  check_ok(diana_norm_2, edge, 2u, DBL_MAX);
}

/* A non-finite entry is an argument error even after the sum overflows. */
static void test_nonfinite(void) {
  double x[4] = {1.0, -2.0, 3.0, -4.0};
  const double after[3] = {DBL_MAX, DBL_MAX, (double)NAN};
  const double inf[2] = {0.0, -HUGE_VAL};
  size_t i;
  size_t j;

  for (j = 0; j < 3u; ++j) {
    for (i = 0; i < 4u; ++i) {
      double saved = x[i];
      x[i] = (double)NAN;
      check_fail(norm[j], x, 4u, DIANA_ERR_ARG);
      x[i] = HUGE_VAL;
      check_fail(norm[j], x, 4u, DIANA_ERR_ARG);
      x[i] = -HUGE_VAL;
      check_fail(norm[j], x, 4u, DIANA_ERR_ARG);
      x[i] = saved;
    }
    check_fail(norm[j], after, 3u, DIANA_ERR_ARG);
    check_fail(norm[j], inf, 2u, DIANA_ERR_ARG);
  }
}

int main(void) {
  test_argument();
  test_zero();
  test_exact();
  test_norm_1_order();
  test_norm_2_order();
  test_norm_2_tie();
  test_norm_2_scale();
  test_extreme();
  test_overflow();
  test_nonfinite();
  return check_report("norm");
}
