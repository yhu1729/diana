#include <float.h>
#include <math.h>
#include <stddef.h>

#include "check.h"
#include "diana/diana.h"

#define SENTINEL 42.0

static void check_ok(const double *y, size_t n, double h, double want) {
  double r = SENTINEL;
  CHECK_EQ_STATUS(diana_trapezoidal(y, n, h, &r), DIANA_OK);
  CHECK(r == want);
  CHECK(!signbit(r) == !signbit(want));
}

static void check_arg(const double *y, size_t n, double h) {
  double r = SENTINEL;
  CHECK_EQ_STATUS(diana_trapezoidal(y, n, h, &r), DIANA_ERR_ARG);
  CHECK(r == SENTINEL);
}

static void test_argument(void) {
  const double y[3] = {1.0, 2.0, 3.0};

  check_arg((const double *)0, 3u, 1.0);
  check_arg((const double *)0, 0u, 1.0);
  CHECK_EQ_STATUS(diana_trapezoidal(y, 3u, 1.0, (double *)0), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_trapezoidal((const double *)0, 3u, 1.0, (double *)0),
                  DIANA_ERR_ARG);
  check_arg(y, 0u, 1.0);
  check_arg(y, 1u, 1.0);
}

static void test_two_node(void) {
  const double y[2] = {1.0, 3.0};

  check_ok(y, 2u, 0.5, 1.0);
  check_ok(y, 2u, 2.0, 4.0);
}

/* The rule is exact for affine f. The samples and h below have few
   significant bits, so every partial sum and the product with h are
   representable and the binary64 result is the exact integral. */
static void test_affine(void) {
  double y[1001];
  size_t i;

  /* f(x) = 2x + 1 on [0, 4], h = 1/2: integral 20 */
  for (i = 0; i < 9u; ++i) {
    y[i] = 1.0 + (double)i;
  }
  check_ok(y, 9u, 0.5, 20.0);
  check_ok(y, 9u, -0.5, -20.0);

  /* y_i = 3i - 1000 changes sign, h = 2^-7: (n - 1) * (y_0 + y_1000) / 2 *
     h = 1000 * 500 / 128 */
  for (i = 0; i < 1001u; ++i) {
    y[i] = 3.0 * (double)i - 1000.0;
  }
  check_ok(y, 1001u, 0.0078125, 3906.25);

  /* f(x) = 7 - x on [0, 3], h = 3/4: integral 16.5 */
  y[0] = 7.0;
  y[1] = 6.25;
  y[2] = 5.5;
  y[3] = 4.75;
  y[4] = 4.0;
  check_ok(y, 5u, 0.75, 16.5);
}

/* The sum runs left to right after the halved endpoint pair: 2^53 + 1 rounds
   to 2^53 (ties to even) at each interior step, so the result is 2^53, not the
   exact 2^53 + 2 that summing the interior first would give. */
static void test_operation_order(void) {
  const double p53 = 9007199254740992.0;
  const double y[4] = {p53, 1.0, 1.0, p53};

  check_ok(y, 4u, 1.0, p53);
}

static void test_zero_step(void) {
  const double y[3] = {1.0, 2.0, 3.0};
  const double big[3] = {DBL_MAX / 2.0, DBL_MAX / 2.0, 0.0};

  check_ok(y, 3u, 0.0, 0.0);
  check_ok(y, 3u, -0.0, -0.0);
  check_ok(big, 3u, 0.0, 0.0);
}

/* Underflow is not an error: 0.5 * 2^-1074 is a tie that rounds to +0. */
static void test_underflow(void) {
  const double y[2] = {0.5, 0.5};

  check_ok(y, 2u, DBL_TRUE_MIN, 0.0);
}

/* Each case has finite samples and h; the overflow is in one operation. */
static void test_overflow(void) {
  const double endpoint[2] = {DBL_MAX, DBL_MAX};
  const double interior[3] = {DBL_MAX, DBL_MAX, 0.0};
  const double product[2] = {DBL_MAX, 0.0};
  const double negative[3] = {-DBL_MAX, -DBL_MAX, 0.0};

  /* y[0] + y[n-1] overflows though h * (y[0] + y[1]) / 2 = DBL_MAX */
  check_arg(endpoint, 2u, 1.0);
  /* h = 0 does not hide it: 0 * inf is NaN */
  check_arg(endpoint, 2u, 0.0);
  check_arg(interior, 3u, 1.0);
  check_arg(negative, 3u, 1.0);
  check_arg(product, 2u, 4.0);
  check_arg(product, 2u, -4.0);
  check_ok(product, 2u, 2.0, DBL_MAX);
}

static void test_nonfinite_sample(void) {
  double y[4] = {1.0, 2.0, 3.0, 4.0};
  size_t i;

  for (i = 0; i < 4u; ++i) {
    double saved = y[i];
    y[i] = (double)NAN;
    check_arg(y, 4u, 1.0);
    y[i] = HUGE_VAL;
    check_arg(y, 4u, 1.0);
    y[i] = -HUGE_VAL;
    check_arg(y, 4u, 1.0);
    y[i] = saved;
  }
  y[0] = HUGE_VAL;
  y[3] = -HUGE_VAL;
  check_arg(y, 4u, 1.0);
  y[0] = 1.0;
  y[1] = HUGE_VAL;
  y[2] = -HUGE_VAL;
  y[3] = 4.0;
  check_arg(y, 4u, 1.0);
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
  test_two_node();
  test_affine();
  test_operation_order();
  test_zero_step();
  test_underflow();
  test_overflow();
  test_nonfinite_sample();
  test_nonfinite_step();
  return check_report("trapezoidal");
}
