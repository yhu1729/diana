#include <float.h>
#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "check.h"
#include "diana/diana.h"

#define SENTINEL 42.0
#define DIM 100u

typedef diana_status (*step_fn)(const double *y, const double *f, size_t d,
                                double h, double *y_out);

static uint64_t bits(double x) {
  uint64_t u;

  memcpy(&u, &x, sizeof u);
  return u;
}

/* Both steps succeed, agree bit for bit, and write only y_out[0 .. d-1]. */
static void check_ok(const double *y, const double *f, size_t d, double h,
                     const double *want) {
  double out[DIM];
  double raw[DIM];
  size_t i;

  for (i = 0; i < DIM; ++i) {
    out[i] = SENTINEL;
    raw[i] = SENTINEL;
  }
  CHECK_EQ_STATUS(diana_euler_step(y, f, d, h, out), DIANA_OK);
  CHECK_EQ_STATUS(diana_euler_step_unchecked(y, f, d, h, raw), DIANA_OK);
  for (i = 0; i < d; ++i) {
    CHECK(out[i] == want[i]);
    CHECK(!signbit(out[i]) == !signbit(want[i]));
  }
  for (i = 0; i < DIM; ++i) {
    CHECK(bits(raw[i]) == bits(out[i]));
  }
  for (i = d; i < DIM; ++i) {
    CHECK(out[i] == SENTINEL);
  }
}

static void check_reject(step_fn step, const double *y, const double *f,
                         size_t d, double h, diana_status want) {
  double out[DIM];
  size_t i;

  for (i = 0; i < DIM; ++i) {
    out[i] = SENTINEL;
  }
  CHECK_EQ_STATUS(step(y, f, d, h, out), want);
  for (i = 0; i < DIM; ++i) {
    CHECK(out[i] == SENTINEL);
  }
}

static void check_arg(const double *y, const double *f, size_t d, double h) {
  check_reject(diana_euler_step, y, f, d, h, DIANA_ERR_ARG);
}

static void check_overflow(const double *y, const double *f, size_t d,
                           double h) {
  check_reject(diana_euler_step, y, f, d, h, DIANA_ERR_OVERFLOW);
}

/* The unchecked step returns DIANA_OK and writes each component as
   computed; want[i] NaN accepts any NaN. */
static void check_raw(const double *y, const double *f, size_t d, double h,
                      const double *want) {
  double out[DIM];
  size_t i;

  for (i = 0; i < DIM; ++i) {
    out[i] = SENTINEL;
  }
  CHECK_EQ_STATUS(diana_euler_step_unchecked(y, f, d, h, out), DIANA_OK);
  for (i = 0; i < d; ++i) {
    if (isnan(want[i])) {
      CHECK(isnan(out[i]));
    } else {
      CHECK(out[i] == want[i]);
      CHECK(!signbit(out[i]) == !signbit(want[i]));
    }
  }
  for (i = d; i < DIM; ++i) {
    CHECK(out[i] == SENTINEL);
  }
}

static void test_argument(void) {
  static const step_fn step[2] = {diana_euler_step, diana_euler_step_unchecked};
  const double y[2] = {1.0, 2.0};
  const double f[2] = {3.0, 4.0};
  size_t k;

  for (k = 0; k < 2u; ++k) {
    check_reject(step[k], (const double *)0, f, 2u, 1.0, DIANA_ERR_ARG);
    check_reject(step[k], y, (const double *)0, 2u, 1.0, DIANA_ERR_ARG);
    check_reject(step[k], (const double *)0, (const double *)0, 2u, 1.0,
                 DIANA_ERR_ARG);
    check_reject(step[k], y, f, 0u, 1.0, DIANA_ERR_ARG);
    CHECK_EQ_STATUS(step[k](y, f, 2u, 1.0, (double *)0), DIANA_ERR_ARG);
    CHECK_EQ_STATUS(
        step[k]((const double *)0, (const double *)0, 0u, 1.0, (double *)0),
        DIANA_ERR_ARG);
  }
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

  check_overflow(zero, max, 1u, 2.0);
  check_overflow(zero, max, 1u, -2.0);
  check_overflow(max, max, 1u, 1.0);
  check_overflow(neg, max, 1u, -1.0);
  /* DBL_MAX + 1 rounds back to DBL_MAX */
  check_ok(max, one, 1u, 1.0, max);
}

/* An overflow is reported only when h and every component of y and f are
   finite: a non-finite input after the overflowing component makes it an
   argument error. */
static void test_overflow_classify(void) {
  const double y[3] = {DBL_MAX, 1.0, 1.0};
  const double f[3] = {DBL_MAX, 1.0, 1.0};
  const double y_nan[3] = {DBL_MAX, 1.0, (double)NAN};
  const double f_inf[3] = {DBL_MAX, 1.0, -HUGE_VAL};

  check_overflow(y, f, 3u, 1.0);
  check_arg(y_nan, f, 3u, 1.0);
  check_arg(y, f_inf, 3u, 1.0);
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

  check_overflow(y, f, 3u, 1.0);
  check_overflow(g, e, 3u, 1.0);
}

/* Inputs the checked step rejects: the unchecked step writes the IEEE
   result of each operation, finite components included. */
static void test_unchecked_nonfinite(void) {
  const double zero[1] = {0.0};
  const double max[1] = {DBL_MAX};
  const double neg[1] = {-DBL_MAX};
  const double inf[1] = {HUGE_VAL};
  const double ninf[1] = {-HUGE_VAL};
  const double nan1[1] = {(double)NAN};
  const double y[3] = {1.0, 2.0, DBL_MAX};
  const double f[3] = {1.0, 1.0, DBL_MAX};
  const double partial[3] = {2.0, 3.0, HUGE_VAL};
  const double g[3] = {-1.0, (double)NAN, 0.5};
  const double e[3] = {2.0, 1.0, -HUGE_VAL};
  const double mixed[3] = {1.0, (double)NAN, -HUGE_VAL};
  const double nan3[3] = {(double)NAN, (double)NAN, (double)NAN};
  const double inf3[3] = {HUGE_VAL, HUGE_VAL, HUGE_VAL};
  const double one3[3] = {1.0, 1.0, 1.0};

  /* overflow in the product, then in the sum */
  check_raw(zero, max, 1u, 2.0, inf);
  check_raw(zero, max, 1u, -2.0, ninf);
  check_raw(max, max, 1u, 1.0, inf);
  check_raw(neg, max, 1u, -1.0, ninf);
  /* inf - inf is NaN; 0 * inf is NaN */
  check_raw(inf, ninf, 1u, 1.0, nan1);
  check_raw(one3, inf, 1u, 0.0, nan1);
  check_raw(y, f, 3u, 1.0, partial);
  check_raw(g, e, 3u, 1.0, mixed);
  check_raw(one3, one3, 3u, (double)NAN, nan3);
  check_raw(zero, one3, 1u, HUGE_VAL, inf);
  check_raw(one3, one3, 3u, HUGE_VAL, inf3);
}

/* Callback wrapper. Each right-hand side below keeps every iterate exactly
   representable, so the expected states are exact. */

struct record {
  unsigned calls;
  double t[8];
  unsigned fail_at;
  void *self;
};

static void decay(double t, const double *y, double *dy, size_t d, void *ctx) {
  size_t i;

  (void)t;
  (void)ctx;
  for (i = 0; i < d; ++i) {
    dy[i] = -y[i];
  }
}

static void rotation(double t, const double *y, double *dy, size_t d,
                     void *ctx) {
  (void)t;
  (void)d;
  (void)ctx;
  dy[0] = y[1];
  dy[1] = -y[0];
}

/* y' = t, recording each time and the context pointer; the derivative is
   infinite from call fail_at on. */
static void ramp(double t, const double *y, double *dy, size_t d, void *ctx) {
  struct record *rec = (struct record *)ctx;

  (void)y;
  (void)d;
  rec->self = ctx;
  if (rec->calls < 8u) {
    rec->t[rec->calls] = t;
  }
  dy[0] = rec->calls >= rec->fail_at ? HUGE_VAL : t;
  rec->calls++;
}

static void test_wrapper_integrate(void) {
  double y[2] = {1.0, 3.0};
  double w[4];
  double r[2] = {1.0, 0.0};
  double z[1] = {0.0};
  struct record rec = {0u, {0.0}, 100u, (void *)0};
  unsigned done = 99u;

  /* y_{k+1} = y_k - y_k / 2 = y_k / 2 */
  CHECK_EQ_STATUS(diana_euler(decay, (void *)0, 0.0, 0.5, 3u, y, 2u, w, &done),
                  DIANA_OK);
  CHECK(done == 3u);
  CHECK(y[0] == 0.125 && y[1] == 0.375);

  /* (y1, y2) <- (y1 + y2, y2 - y1): (1, 0), (1, -1), (0, -2), (-2, -2) */
  CHECK_EQ_STATUS(
      diana_euler(rotation, (void *)0, 0.0, 1.0, 3u, r, 2u, w, (unsigned *)0),
      DIANA_OK);
  CHECK(r[0] == -2.0 && r[1] == -2.0);

  /* y' = t from t0 = 1 with h = 1/4: times 1, 1.25, 1.5, 1.75 and
     y = (1 + 1.25 + 1.5 + 1.75) / 4 */
  CHECK_EQ_STATUS(diana_euler(ramp, &rec, 1.0, 0.25, 4u, z, 1u, w, &done),
                  DIANA_OK);
  CHECK(done == 4u && rec.calls == 4u && rec.self == (void *)&rec);
  CHECK(rec.t[0] == 1.0 && rec.t[1] == 1.25 && rec.t[2] == 1.5 &&
        rec.t[3] == 1.75);
  CHECK(z[0] == 1.375);
}

static void test_wrapper_no_step(void) {
  double y[1] = {2.0};
  double w[2];
  struct record rec = {0u, {0.0}, 100u, (void *)0};
  unsigned done = 99u;

  CHECK_EQ_STATUS(diana_euler(ramp, &rec, 0.0, 1.0, 0u, y, 1u, w, &done),
                  DIANA_OK);
  CHECK(done == 0u && rec.calls == 0u && y[0] == 2.0);
}

static void test_wrapper_argument(void) {
  double y[1] = {2.0};
  double w[2];
  struct record rec = {0u, {0.0}, 100u, (void *)0};
  unsigned done = 99u;

  CHECK_EQ_STATUS(
      diana_euler((diana_ode_fn)0, &rec, 0.0, 1.0, 1u, y, 1u, w, &done),
      DIANA_ERR_ARG);
  CHECK(done == 0u);
  CHECK_EQ_STATUS(
      diana_euler(ramp, &rec, 0.0, 1.0, 1u, (double *)0, 1u, w, &done),
      DIANA_ERR_ARG);
  CHECK_EQ_STATUS(
      diana_euler(ramp, &rec, 0.0, 1.0, 1u, y, 1u, (double *)0, &done),
      DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_euler(ramp, &rec, 0.0, 1.0, 1u, y, 0u, w, &done),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(
      diana_euler((diana_ode_fn)0, &rec, 0.0, 1.0, 1u, y, 1u, w, (unsigned *)0),
      DIANA_ERR_ARG);
  CHECK(rec.calls == 0u && y[0] == 2.0);
}

/* A failing step leaves y at the last good state and done at the number of
   completed steps. */
static void test_wrapper_failure(void) {
  double z[1] = {0.0};
  double w[2];
  double big[1] = {DBL_MAX / 2.0};
  struct record rec = {0u, {0.0}, 2u, (void *)0};
  unsigned done = 99u;

  /* y' = t from t0 = 0, h = 1: steps at t = 0 and t = 1 succeed, the third
     derivative is infinite */
  CHECK_EQ_STATUS(diana_euler(ramp, &rec, 0.0, 1.0, 5u, z, 1u, w, &done),
                  DIANA_ERR_ARG);
  CHECK(done == 2u && rec.calls == 3u && z[0] == 1.0);

  /* y' = -y with h = -2 overflows on the first step: y + 2y */
  CHECK_EQ_STATUS(
      diana_euler(decay, (void *)0, 0.0, -2.0, 3u, big, 1u, w, &done),
      DIANA_ERR_OVERFLOW);
  CHECK(done == 0u && big[0] == DBL_MAX / 2.0);
}

int main(void) {
  test_argument();
  test_exact();
  test_no_contraction();
  test_zero_step();
  test_underflow();
  test_overflow();
  test_overflow_classify();
  test_nonfinite();
  test_failure_keeps_output();
  test_unchecked_nonfinite();
  test_wrapper_integrate();
  test_wrapper_no_step();
  test_wrapper_argument();
  test_wrapper_failure();
  return check_report("euler");
}
