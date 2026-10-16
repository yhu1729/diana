#include <float.h>
#include <math.h>
#include <stddef.h>

#include "check.h"
#include "diana/diana.h"

#define SENTINEL 42.0
#define DIM 100u

static void check_ok(const double *y, const double *f, size_t d, double h,
                     const double *want) {
  double out[DIM];
  size_t i;

  for (i = 0; i < d; ++i) {
    out[i] = SENTINEL;
  }
  CHECK_EQ_STATUS(diana_euler_step(y, f, d, h, out), DIANA_OK);
  for (i = 0; i < d; ++i) {
    CHECK(out[i] == want[i]);
    CHECK(!signbit(out[i]) == !signbit(want[i]));
  }
}

static void check_arg(const double *y, const double *f, size_t d, double h) {
  double out[DIM];
  size_t i;

  for (i = 0; i < DIM; ++i) {
    out[i] = SENTINEL;
  }
  CHECK_EQ_STATUS(diana_euler_step(y, f, d, h, out), DIANA_ERR_ARG);
  for (i = 0; i < DIM; ++i) {
    CHECK(out[i] == SENTINEL);
  }
}

static void test_argument(void) {
  const double y[2] = {1.0, 2.0};
  const double f[2] = {3.0, 4.0};

  check_arg((const double *)0, f, 2u, 1.0);
  check_arg(y, (const double *)0, 2u, 1.0);
  check_arg((const double *)0, (const double *)0, 2u, 1.0);
  check_arg(y, f, 0u, 1.0);
  CHECK_EQ_STATUS(diana_euler_step(y, f, 2u, 1.0, (double *)0), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_euler_step((const double *)0, (const double *)0, 0u,
                                   1.0, (double *)0),
                  DIANA_ERR_ARG);
}

/* Samples and h with few significant bits: the product and the sum are
   exact. */
static void test_exact(void) {
  const double y[3] = {1.0, -2.0, 0.5};
  const double f[3] = {3.0, 4.0, -8.0};
  const double want[3] = {1.75, -1.0, -1.5};
  double ys[DIM], fs[DIM], ws[DIM];
  size_t i;

  check_ok(y, f, 3u, 0.25, want);
  check_ok(y, f, 1u, 0.25, want);
  for (i = 0; i < DIM; ++i) {
    ys[i] = (double)i - 50.0;
    fs[i] = 3.0 - (double)i;
    ws[i] = 0.5 * (double)i - 48.5;
  }
  check_ok(ys, fs, DIM, 0.5, ws);
}

/* y + h * f with a separately rounded product: h * f = 1 - 2^-104 rounds to
   1, so the result is +0. A fused multiply-add would give -2^-104. */
static void test_no_contraction(void) {
  const double y[1] = {-1.0};
  const double f[1] = {1.0 - DBL_EPSILON};
  const double want[1] = {0.0};

  check_ok(y, f, 1u, 1.0 + DBL_EPSILON, want);
}

static void test_zero_step(void) {
  const double y[3] = {-0.0, 2.0, 0.0};
  const double f[3] = {-3.0, 5.0, -1.0};
  const double want[3] = {-0.0, 2.0, 0.0};

  check_ok(y, f, 3u, 0.0, want);
}

/* Underflow is not an error: 0.5 * 2^-1074 is a tie that rounds to +0. */
static void test_underflow(void) {
  const double y[1] = {0.0};
  const double f[1] = {DBL_TRUE_MIN};
  const double want[1] = {0.0};

  check_ok(y, f, 1u, 0.5, want);
}

/* Each case has finite y, f and h; the overflow is in one operation. */
static void test_overflow(void) {
  const double zero[1] = {0.0};
  const double max[1] = {DBL_MAX};
  const double one[1] = {1.0};
  const double neg[1] = {-DBL_MAX};

  check_arg(zero, max, 1u, 2.0);
  check_arg(zero, max, 1u, -2.0);
  check_arg(max, max, 1u, 1.0);
  check_arg(neg, max, 1u, -1.0);
  /* DBL_MAX + 1 rounds back to DBL_MAX */
  check_ok(max, one, 1u, 1.0, max);
}

static void test_nonfinite(void) {
  double y[3] = {1.0, 2.0, 3.0};
  double f[3] = {4.0, 5.0, 6.0};
  const double inf[1] = {HUGE_VAL};
  const double ninf[1] = {-HUGE_VAL};
  size_t i;

  for (i = 0; i < 3u; ++i) {
    double saved_y = y[i];
    double saved_f = f[i];
    y[i] = (double)NAN;
    check_arg(y, f, 3u, 1.0);
    y[i] = HUGE_VAL;
    check_arg(y, f, 3u, 1.0);
    y[i] = saved_y;
    f[i] = (double)NAN;
    check_arg(y, f, 3u, 1.0);
    f[i] = -HUGE_VAL;
    check_arg(y, f, 3u, 1.0);
    f[i] = saved_f;
  }
  check_arg(y, f, 3u, (double)NAN);
  check_arg(y, f, 3u, HUGE_VAL);
  check_arg(y, f, 3u, -HUGE_VAL);
  /* inf - inf is NaN; 0 * inf is NaN */
  check_arg(inf, ninf, 1u, 1.0);
  check_arg(y, inf, 1u, 0.0);
}

/* The first pass checks every component before the second writes any: a
   failure in the last or the first component leaves the output untouched. */
static void test_failure_keeps_output(void) {
  const double y[3] = {1.0, 2.0, DBL_MAX};
  const double f[3] = {1.0, 1.0, DBL_MAX};
  const double g[3] = {DBL_MAX, 2.0, 3.0};
  const double e[3] = {DBL_MAX, 1.0, 1.0};

  check_arg(y, f, 3u, 1.0);
  check_arg(g, e, 3u, 1.0);
}

int main(void) {
  test_argument();
  test_exact();
  test_no_contraction();
  test_zero_step();
  test_underflow();
  test_overflow();
  test_nonfinite();
  test_failure_keeps_output();
  return check_report("euler");
}
