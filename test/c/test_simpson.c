#include <float.h>
#include <math.h>
#include <stddef.h>

#include "check.h"
#include "diana/diana.h"

#define SENTINEL 42.0

static void check_ok(const double *y, size_t n, double h, double want) {
  double r = SENTINEL;
  CHECK_EQ_STATUS(diana_simpson(y, n, h, &r), DIANA_OK);
  CHECK(r == want);
  CHECK(!signbit(r) == !signbit(want));
}

static void check_arg(const double *y, size_t n, double h) {
  double r = SENTINEL;
  CHECK_EQ_STATUS(diana_simpson(y, n, h, &r), DIANA_ERR_ARG);
  CHECK(r == SENTINEL);
}

static void check_overflow(const double *y, size_t n, double h) {
  double r = SENTINEL;
  CHECK_EQ_STATUS(diana_simpson(y, n, h, &r), DIANA_ERR_OVERFLOW);
  CHECK(r == SENTINEL);
}

static void test_argument(void) {
  const double y[5] = {1.0, 2.0, 3.0, 4.0, 5.0};

  check_arg((const double *)0, 3u, 1.0);
  check_arg((const double *)0, 0u, 1.0);
  CHECK_EQ_STATUS(diana_simpson(y, 3u, 1.0, (double *)0), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_simpson((const double *)0, 3u, 1.0, (double *)0),
                  DIANA_ERR_ARG);
  check_arg(y, 0u, 1.0);
  check_arg(y, 1u, 1.0);
  check_arg(y, 2u, 1.0);
  check_arg(y, 4u, 1.0);
}

static void test_three_node(void) {
  const double y[3] = {1.0, 2.0, 3.0};

  check_ok(y, 3u, 3.0, 12.0);
  check_ok(y, 3u, 0.75, 3.0);
  check_ok(y, 3u, -3.0, -12.0);
}

/* The rule is exact for cubic f. The samples and h below have few
   significant bits, so every partial sum and the product with h are
   representable and only the final division by 3 can round. */
static void test_cubic(void) {
  double y[1001];
  size_t i;

  /* f(x) = x^3 on [0, 4], h = 1: integral 64 */
  for (i = 0; i < 5u; ++i) {
    y[i] = (double)(i * i * i);
  }
  check_ok(y, 5u, 1.0, 64.0);

  /* f(x) = x^3 - 2x^2 + x + 1 on [-1, 3], h = 1/2: integral 28/3, and the
     weighted sum is exactly 56 */
  for (i = 0; i < 9u; ++i) {
    double x = -1.0 + 0.5 * (double)i;
    y[i] = x * x * x - 2.0 * x * x + x + 1.0;
  }
  check_ok(y, 9u, 0.5, 28.0 / 3.0);
  check_ok(y, 9u, -0.5, -28.0 / 3.0);

  /* y_i = (i - 400)^3 + 7 changes sign, h = 2^-3: integral of x^3 + 7 over
     [-400, 600] is 26000007000, times h is 3250000875 */
  for (i = 0; i < 1001u; ++i) {
    double x = (double)i - 400.0;
    y[i] = x * x * x + 7.0;
  }
  check_ok(y, 1001u, 1.0, 26000007000.0);
  check_ok(y, 1001u, 0.125, 3250000875.0);
}

/* Pins the operation order: the endpoint pair is added first, then 4 times
   the odd sum, then 2 times the even sum, and each interior sum runs left to
   right from +0. */
static void test_operation_order(void) {
  const double p53 = 9007199254740992.0;
  /* The endpoints cancel exactly. Adding the weighted interior to 2^53 first
     would round 4.5 to 4. */
  const double cancel[5] = {p53, 0.5, 0.25, 0.5, -p53};
  /* 2^53 + 1 rounds to 2^53 (ties to even), so the odd sum is 0; summing
     right to left would give 1 and the result 4. */
  const double odd[7] = {0.0, p53, 0.0, 1.0, 0.0, -p53, 0.0};
  /* The same for the even sum; right to left would give the result 2. */
  const double even[9] = {0.0, 0.0, p53, 0.0, 1.0, 0.0, -p53, 0.0, 0.0};

  check_ok(cancel, 5u, 3.0, 4.5);
  check_ok(odd, 7u, 3.0, 0.0);
  check_ok(even, 9u, 3.0, 0.0);
}

static void test_zero_step(void) {
  const double y[3] = {1.0, 2.0, 3.0};
  const double big[3] = {DBL_MAX / 2.0, DBL_MAX / 8.0, 0.0};

  check_ok(y, 3u, 0.0, 0.0);
  check_ok(y, 3u, -0.0, -0.0);
  check_ok(big, 3u, 0.0, 0.0);
}

/* Underflow is not an error: 2^-1074 / 3 rounds to +0. */
static void test_underflow(void) {
  const double y[3] = {0.5, 0.0, 0.5};

  check_ok(y, 3u, DBL_TRUE_MIN, 0.0);
}

/* Each case has finite samples and h; the overflow is in one operation. */
static void test_overflow(void) {
  const double endpoint[3] = {DBL_MAX, 0.0, DBL_MAX};
  const double odd_scale[3] = {0.0, DBL_MAX, 0.0};
  const double odd_sum[5] = {0.0, DBL_MAX, 0.0, DBL_MAX, 0.0};
  const double even_scale[5] = {0.0, 0.0, DBL_MAX, 0.0, 0.0};
  const double even_sum[7] = {0.0, 0.0, DBL_MAX, 0.0, DBL_MAX, 0.0, 0.0};
  const double odd_add[3] = {DBL_MAX, DBL_MAX / 4.0, 0.0};
  const double even_add[5] = {DBL_MAX, 0.0, DBL_MAX / 2.0, 0.0, 0.0};
  const double negative[3] = {-DBL_MAX, 0.0, -DBL_MAX};
  const double one[3] = {1.0, 1.0, 1.0};
  const double max[3] = {DBL_MAX, 0.0, 0.0};

  check_overflow(endpoint, 3u, 1.0);
  /* h = 0 does not hide it: 0 * inf is NaN */
  check_overflow(endpoint, 3u, 0.0);
  /* 4 * y[1] overflows though h * 4 * y[1] / 3 = DBL_MAX / 3 */
  check_overflow(odd_scale, 3u, 0.25);
  check_overflow(odd_sum, 5u, 1.0);
  check_overflow(even_scale, 5u, 1.0);
  check_overflow(even_sum, 7u, 1.0);
  check_overflow(odd_add, 3u, 1.0);
  check_overflow(even_add, 5u, 1.0);
  check_overflow(negative, 3u, 1.0);
  /* h * s overflows though h * s / 3 = DBL_MAX / 2 */
  check_overflow(one, 3u, DBL_MAX / 4.0);
  check_overflow(one, 3u, -DBL_MAX / 4.0);
  check_ok(max, 3u, 1.0, DBL_MAX / 3.0);
}

/* An overflow is reported only when h and every sample are finite: a
   non-finite sample after those that overflow makes it an argument error. */
static void test_overflow_classify(void) {
  const double y[5] = {1.0, DBL_MAX, 1.0, DBL_MAX, 1.0};
  const double y_nan[5] = {1.0, DBL_MAX, 1.0, DBL_MAX, (double)NAN};
  const double y_inf[5] = {1.0, DBL_MAX, 1.0, DBL_MAX, HUGE_VAL};

  check_overflow(y, 5u, 1.0);
  check_arg(y_nan, 5u, 1.0);
  check_arg(y_inf, 5u, 1.0);
}

static void test_nonfinite_sample(void) {
  double y[5] = {1.0, 2.0, 3.0, 4.0, 5.0};
  size_t i;

  for (i = 0; i < 5u; ++i) {
    double saved = y[i];
    y[i] = (double)NAN;
    check_arg(y, 5u, 1.0);
    y[i] = HUGE_VAL;
    check_arg(y, 5u, 1.0);
    y[i] = -HUGE_VAL;
    check_arg(y, 5u, 1.0);
    y[i] = saved;
  }
  y[0] = HUGE_VAL;
  y[4] = -HUGE_VAL;
  check_arg(y, 5u, 1.0);
  y[0] = 1.0;
  y[4] = 5.0;
  y[1] = HUGE_VAL;
  y[3] = -HUGE_VAL;
  check_arg(y, 5u, 1.0);
}

static void test_nonfinite_step(void) {
  const double y[3] = {1.0, 2.0, 3.0};
  const double zero[3] = {0.0, 0.0, 0.0};

  check_arg(y, 3u, (double)NAN);
  check_arg(y, 3u, HUGE_VAL);
  check_arg(y, 3u, -HUGE_VAL);
  check_arg(zero, 3u, HUGE_VAL);
}

int main(void) {
  test_argument();
  test_three_node();
  test_cubic();
  test_operation_order();
  test_zero_step();
  test_underflow();
  test_overflow();
  test_overflow_classify();
  test_nonfinite_sample();
  test_nonfinite_step();
  return check_report("simpson");
}
