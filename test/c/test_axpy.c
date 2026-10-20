#include <float.h>
#include <math.h>
#include <stddef.h>
#include <string.h>

#include "check.h"
#include "diana/diana.h"

#define SENTINEL 42.0

static int same(double a, double b) {
  return a == b && signbit(a) == signbit(b);
}

static void check_ok(double a, const double *x, const double *y0, size_t n,
                     const double *want) {
  double y[8];
  size_t i;

  memcpy(y, y0, n * sizeof *y);
  CHECK_EQ_STATUS(diana_axpy(a, x, n, y), DIANA_OK);
  for (i = 0; i < n; ++i) {
    CHECK(same(y[i], want[i]));
  }
}

/* y keeps its bits on every error. */
static void check_fail(double a, const double *x, const double *y0, size_t n,
                       diana_status want) {
  double y[8];

  memcpy(y, y0, n * sizeof *y);
  CHECK_EQ_STATUS(diana_axpy(a, x, n, y), want);
  CHECK(memcmp(y, y0, n * sizeof *y) == 0);
}

static void test_argument(void) {
  const double x[2] = {1.0, 2.0};
  double y[2] = {SENTINEL, SENTINEL};

  CHECK_EQ_STATUS(diana_axpy(1.0, (const double *)0, 2u, y), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_axpy(1.0, (const double *)0, 0u, y), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_axpy(1.0, x, 2u, (double *)0), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_axpy(1.0, x, 0u, (double *)0), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_axpy(1.0, (const double *)0, 2u, (double *)0),
                  DIANA_ERR_ARG);
  CHECK(y[0] == SENTINEL && y[1] == SENTINEL);
  /* a is tested before the loop, so also for the empty vector */
  check_fail((double)NAN, x, y, 2u, DIANA_ERR_ARG);
  check_fail(HUGE_VAL, x, y, 2u, DIANA_ERR_ARG);
  check_fail(-HUGE_VAL, x, y, 0u, DIANA_ERR_ARG);
  check_fail((double)NAN, x, y, 0u, DIANA_ERR_ARG);
}

/* n = 0 with finite a succeeds and touches nothing. */
static void test_empty(void) {
  const double x[1] = {(double)NAN};
  double y[1] = {SENTINEL};

  CHECK_EQ_STATUS(diana_axpy(1.0, x, 0u, y), DIANA_OK);
  CHECK(y[0] == SENTINEL);
}

/* Few significant bits: the product and the sum are exact. */
static void test_exact(void) {
  const double x[3] = {2.0, 4.0, -8.0};
  const double y[3] = {1.0, -1.0, 0.25};
  const double want[3] = {2.0, 1.0, -3.75};
  const double back[3] = {1.0, -1.0, 0.25};
  double z[3];

  check_ok(0.5, x, y, 3u, want);
  /* the update by -a undoes the update by a when both are exact */
  memcpy(z, y, sizeof z);
  CHECK_EQ_STATUS(diana_axpy(0.5, x, 3u, z), DIANA_OK);
  CHECK_EQ_STATUS(diana_axpy(-0.5, x, 3u, z), DIANA_OK);
  CHECK(same(z[0], back[0]) && same(z[1], back[1]) && same(z[2], back[2]));
}

/* a = ±0 adds the signed zero a * x[i]: -0 + +0 is +0 and -0 + -0 is -0, so
   a = +0 turns a -0 entry with a positive x[i] into +0. A NaN or infinite x is
   still an argument error. */
static void test_zero_coefficient(void) {
  const double x[4] = {1.0, -1.0, 1.0, -1.0};
  const double y[4] = {-0.0, -0.0, 0.0, 0.0};
  const double want_pos[4] = {0.0, -0.0, 0.0, 0.0};
  const double want_neg[4] = {-0.0, 0.0, 0.0, 0.0};
  const double inf[1] = {HUGE_VAL};
  const double one[1] = {1.0};

  check_ok(0.0, x, y, 4u, want_pos);
  check_ok(-0.0, x, y, 4u, want_neg);
  check_fail(0.0, inf, one, 1u, DIANA_ERR_ARG);
}

/* a * x = 1 - 2^-104 rounds to 1, so y + a * x is +0; a fused multiply-add
   would give -2^-104. */
static void test_no_contraction(void) {
  const double x[1] = {1.0 - DBL_EPSILON};
  const double y[1] = {-1.0};
  const double want[1] = {0.0};

  check_ok(1.0 + DBL_EPSILON, x, y, 1u, want);
}

/* The product is rounded on its own: 2^-1074 / 2 is a tie that rounds to
   even, +0, and 1.5 * 2^-1074 rounds up to 2^-1073. */
static void test_underflow(void) {
  const double x[1] = {DBL_TRUE_MIN};
  const double y[1] = {0.0};
  const double zero[1] = {0.0};
  const double up[1] = {2.0 * DBL_TRUE_MIN};

  check_ok(0.5, x, y, 1u, zero);
  check_ok(1.5, x, y, 1u, up);
}

/* Each case has finite inputs; only the product or the sum overflows, and a
   cancelling sum of extreme values does not. */
static void test_overflow(void) {
  const double max[1] = {DBL_MAX};
  const double zero[1] = {0.0};
  const double neg_max[1] = {-DBL_MAX};
  const double x3[3] = {1.0, 2.0, DBL_MAX};
  const double y3[3] = {1.0, 1.0, DBL_MAX};
  const double cancel[1] = {0.0};

  check_fail(2.0, max, zero, 1u, DIANA_ERR_OVERFLOW);
  check_fail(1.0, max, max, 1u, DIANA_ERR_OVERFLOW);
  check_fail(-1.0, max, neg_max, 1u, DIANA_ERR_OVERFLOW);
  check_fail(1.0, x3, y3, 3u, DIANA_ERR_OVERFLOW);
  check_ok(-1.0, max, max, 1u, cancel);
}

/* A NaN or infinite entry anywhere is an argument error, also when an
   earlier component overflows. */
static void test_nonfinite(void) {
  double x[4] = {1.0, -2.0, 3.0, -4.0};
  double y[4] = {0.5, 0.25, -1.0, 2.0};
  const double x3[3] = {DBL_MAX, 1.0, 1.0};
  const double y3[3] = {DBL_MAX, 1.0, (double)NAN};
  const double x3_inf[3] = {DBL_MAX, 1.0, -HUGE_VAL};
  const double y3_ok[3] = {DBL_MAX, 1.0, 1.0};
  size_t i;

  for (i = 0; i < 4u; ++i) {
    double saved = x[i];
    x[i] = (double)NAN;
    check_fail(0.5, x, y, 4u, DIANA_ERR_ARG);
    x[i] = HUGE_VAL;
    check_fail(0.5, x, y, 4u, DIANA_ERR_ARG);
    x[i] = saved;
    saved = y[i];
    y[i] = (double)NAN;
    check_fail(0.5, x, y, 4u, DIANA_ERR_ARG);
    y[i] = -HUGE_VAL;
    check_fail(0.5, x, y, 4u, DIANA_ERR_ARG);
    y[i] = saved;
  }
  check_fail(1.0, x3, y3, 3u, DIANA_ERR_ARG);
  check_fail(1.0, x3_inf, y3_ok, 3u, DIANA_ERR_ARG);
}

/* A longer vector against the same expression evaluated here, which the
   build also compiles without contraction. */
static void test_sequential(void) {
  double x[8];
  double y[8];
  double want[8];
  const double a = 1.0 / 3.0;
  size_t i;

  for (i = 0; i < 8u; ++i) {
    x[i] = 0.1 * (double)(i + 1u) * ((i & 1u) ? -1.0 : 1.0);
    y[i] = 1.0 / (double)(i + 2u);
    want[i] = y[i] + a * x[i];
  }
  check_ok(a, x, y, 8u, want);
}

int main(void) {
  test_argument();
  test_empty();
  test_exact();
  test_zero_coefficient();
  test_no_contraction();
  test_underflow();
  test_overflow();
  test_nonfinite();
  test_sequential();
  return check_report("axpy");
}
