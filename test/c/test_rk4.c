#include <float.h>
#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "check.h"
#include "diana/diana.h"

#define SENTINEL 42.0
#define DIM 100u

typedef diana_status (*stage_fn)(const double *y, const double *k, size_t d,
                                 double h, int stage, double *y_out);
typedef diana_status (*step_fn)(const double *y, const double *k1,
                                const double *k2, const double *k3,
                                const double *k4, size_t d, double h,
                                double *y_out);

static uint64_t bits(double x) {
  uint64_t u;

  memcpy(&u, &x, sizeof u);
  return u;
}

static void check_same(const double *out, const double *want, size_t d) {
  size_t i;

  for (i = 0; i < d; ++i) {
    CHECK(out[i] == want[i]);
    CHECK(!signbit(out[i]) == !signbit(want[i]));
  }
}

static void fill(double *out) {
  size_t i;

  for (i = 0; i < DIM; ++i) {
    out[i] = SENTINEL;
  }
}

static void check_untouched(const double *out) {
  size_t i;

  for (i = 0; i < DIM; ++i) {
    CHECK(out[i] == SENTINEL);
  }
}

/* The checked and unchecked results agree bit for bit in every slot, and
   only out[0 .. d-1] is written. */
static void check_agree(const double *out, const double *raw, size_t d) {
  size_t i;

  for (i = 0; i < DIM; ++i) {
    CHECK(bits(raw[i]) == bits(out[i]));
  }
  for (i = d; i < DIM; ++i) {
    CHECK(out[i] == SENTINEL);
  }
}

/* An unchecked result written as computed; want[i] NaN accepts any NaN. */
static void check_raw(const double *out, const double *want, size_t d) {
  size_t i;

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

static void stage_ok(const double *y, const double *k, size_t d, double h,
                     int stage, const double *want) {
  double out[DIM];
  double raw[DIM];

  fill(out);
  fill(raw);
  CHECK_EQ_STATUS(diana_rk4_stage(y, k, d, h, stage, out), DIANA_OK);
  CHECK_EQ_STATUS(diana_rk4_stage_unchecked(y, k, d, h, stage, raw), DIANA_OK);
  check_same(out, want, d);
  check_agree(out, raw, d);
}

static void stage_reject(stage_fn fn, const double *y, const double *k,
                         size_t d, double h, int stage) {
  double out[DIM];

  fill(out);
  CHECK_EQ_STATUS(fn(y, k, d, h, stage, out), DIANA_ERR_ARG);
  check_untouched(out);
}

static void stage_arg(const double *y, const double *k, size_t d, double h,
                      int stage) {
  stage_reject(diana_rk4_stage, y, k, d, h, stage);
}

static void stage_raw(const double *y, const double *k, size_t d, double h,
                      int stage, const double *want) {
  double out[DIM];

  fill(out);
  CHECK_EQ_STATUS(diana_rk4_stage_unchecked(y, k, d, h, stage, out), DIANA_OK);
  check_raw(out, want, d);
}

static void step_ok(const double *y, const double *k1, const double *k2,
                    const double *k3, const double *k4, size_t d, double h,
                    const double *want) {
  double out[DIM];
  double raw[DIM];

  fill(out);
  fill(raw);
  CHECK_EQ_STATUS(diana_rk4_step(y, k1, k2, k3, k4, d, h, out), DIANA_OK);
  CHECK_EQ_STATUS(diana_rk4_step_unchecked(y, k1, k2, k3, k4, d, h, raw),
                  DIANA_OK);
  check_same(out, want, d);
  check_agree(out, raw, d);
}

static void step_reject(step_fn fn, const double *y, const double *k1,
                        const double *k2, const double *k3, const double *k4,
                        size_t d, double h) {
  double out[DIM];

  fill(out);
  CHECK_EQ_STATUS(fn(y, k1, k2, k3, k4, d, h, out), DIANA_ERR_ARG);
  check_untouched(out);
}

static void step_arg(const double *y, const double *k1, const double *k2,
                     const double *k3, const double *k4, size_t d, double h) {
  step_reject(diana_rk4_step, y, k1, k2, k3, k4, d, h);
}

static void step_raw(const double *y, const double *k1, const double *k2,
                     const double *k3, const double *k4, size_t d, double h,
                     const double *want) {
  double out[DIM];

  fill(out);
  CHECK_EQ_STATUS(diana_rk4_step_unchecked(y, k1, k2, k3, k4, d, h, out),
                  DIANA_OK);
  check_raw(out, want, d);
}

static void test_stage_argument(void) {
  static const stage_fn fn[2] = {diana_rk4_stage, diana_rk4_stage_unchecked};
  const double y[2] = {1.0, 2.0};
  const double k[2] = {3.0, 4.0};
  size_t n;

  for (n = 0; n < 2u; ++n) {
    stage_reject(fn[n], (const double *)0, k, 2u, 1.0, 2);
    stage_reject(fn[n], y, (const double *)0, 2u, 1.0, 2);
    stage_reject(fn[n], y, k, 0u, 1.0, 2);
    stage_reject(fn[n], y, k, 2u, 1.0, 1);
    stage_reject(fn[n], y, k, 2u, 1.0, 5);
    stage_reject(fn[n], y, k, 2u, 1.0, 0);
    stage_reject(fn[n], y, k, 2u, 1.0, -3);
    CHECK_EQ_STATUS(fn[n](y, k, 2u, 1.0, 2, (double *)0), DIANA_ERR_ARG);
    CHECK_EQ_STATUS(
        fn[n]((const double *)0, (const double *)0, 0u, 1.0, 0, (double *)0),
        DIANA_ERR_ARG);
  }
}

/* Samples and h with few significant bits: the coefficient, the product and
   the sum are exact. Stages 2 and 3 step by h/2, stage 4 by h. */
static void test_stage_exact(void) {
  const double y[3] = {1.0, -2.0, 0.5};
  const double k[3] = {3.0, 4.0, -8.0};
  const double half[3] = {1.75, -1.0, -1.5};
  const double full[3] = {2.5, 0.0, -3.5};
  double ys[DIM], ks[DIM], ws[DIM];
  size_t i;

  stage_ok(y, k, 3u, 0.5, 2, half);
  stage_ok(y, k, 3u, 0.5, 3, half);
  stage_ok(y, k, 3u, 0.5, 4, full);
  stage_ok(y, k, 1u, 0.5, 4, full);
  for (i = 0; i < DIM; ++i) {
    ys[i] = (double)i - 50.0;
    ks[i] = 3.0 - (double)i;
    ws[i] = 0.5 * (double)i - 48.5;
  }
  stage_ok(ys, ks, DIM, 1.0, 2, ws);
  stage_ok(ys, ks, DIM, 0.5, 4, ws);
}

/* y + c * k with a separately rounded product: c * k = 1 - 2^-104 rounds to
   1, so the result is +0. A fused multiply-add would give -2^-104. */
static void test_stage_no_contraction(void) {
  const double y[1] = {-1.0};
  const double k[1] = {1.0 - DBL_EPSILON};
  const double want[1] = {0.0};

  stage_ok(y, k, 1u, 1.0 + DBL_EPSILON, 4, want);
  stage_ok(y, k, 1u, 2.0 + 2.0 * DBL_EPSILON, 2, want);
}

/* The coefficient h/2 is rounded before the product: for h = 3 * 2^-1074,
   h/2 rounds to 2 * 2^-1074 (a tie, to even), so the stage is 2^-1063 where
   (h * k)/2 = 3 * 2^-1065 is exact. */
static void test_stage_coefficient(void) {
  const double y[1] = {0.0};
  const double k[1] = {1024.0};
  const double want[1] = {2048.0 * DBL_TRUE_MIN};

  stage_ok(y, k, 1u, 3.0 * DBL_TRUE_MIN, 2, want);
  stage_ok(y, k, 1u, 3.0 * DBL_TRUE_MIN, 3, want);
}

static void test_stage_zero_step(void) {
  const double y[3] = {-0.0, 2.0, 0.0};
  const double k[3] = {-3.0, 5.0, -1.0};

  stage_ok(y, k, 3u, 0.0, 2, y);
  stage_ok(y, k, 3u, 0.0, 4, y);
}

/* Each case has finite y, k and h; the overflow is in one operation. */
static void test_stage_overflow(void) {
  const double zero[1] = {0.0};
  const double max[1] = {DBL_MAX};
  const double two[1] = {2.0};
  const double four[1] = {4.0};

  stage_arg(zero, max, 1u, 2.0, 4);
  stage_arg(zero, four, 1u, DBL_MAX, 2);
  stage_arg(max, max, 1u, 2.0, 3);
  /* (DBL_MAX/2) * 2 is DBL_MAX: the coefficient h/2 keeps it finite */
  stage_ok(zero, two, 1u, DBL_MAX, 2, max);
}

static void test_stage_nonfinite(void) {
  double y[3] = {1.0, 2.0, 3.0};
  double k[3] = {4.0, 5.0, 6.0};
  const double inf[1] = {HUGE_VAL};
  const double ninf[1] = {-HUGE_VAL};
  size_t i;

  for (i = 0; i < 3u; ++i) {
    double saved_y = y[i];
    double saved_k = k[i];
    y[i] = (double)NAN;
    stage_arg(y, k, 3u, 1.0, 2);
    y[i] = HUGE_VAL;
    stage_arg(y, k, 3u, 1.0, 4);
    y[i] = saved_y;
    k[i] = (double)NAN;
    stage_arg(y, k, 3u, 1.0, 3);
    k[i] = -HUGE_VAL;
    stage_arg(y, k, 3u, 1.0, 4);
    k[i] = saved_k;
  }
  stage_arg(y, k, 3u, (double)NAN, 2);
  stage_arg(y, k, 3u, HUGE_VAL, 3);
  stage_arg(y, k, 3u, -HUGE_VAL, 4);
  /* inf - inf is NaN; 0 * inf is NaN */
  stage_arg(inf, ninf, 1u, 2.0, 2);
  stage_arg(y, inf, 1u, 0.0, 4);
}

/* The first pass checks every component before the second writes any. */
static void test_stage_failure_keeps_output(void) {
  const double y[3] = {1.0, 2.0, DBL_MAX};
  const double k[3] = {1.0, 1.0, DBL_MAX};
  const double g[3] = {DBL_MAX, 2.0, 3.0};
  const double e[3] = {DBL_MAX, 1.0, 1.0};

  stage_arg(y, k, 3u, 2.0, 4);
  stage_arg(g, e, 3u, 2.0, 4);
}

static void test_step_argument(void) {
  static const step_fn fn[2] = {diana_rk4_step, diana_rk4_step_unchecked};
  const double v[2] = {1.0, 2.0};
  const double *const z = (const double *)0;
  double out[2] = {SENTINEL, SENTINEL};
  size_t n;

  for (n = 0; n < 2u; ++n) {
    step_reject(fn[n], z, v, v, v, v, 2u, 1.0);
    step_reject(fn[n], v, z, v, v, v, 2u, 1.0);
    step_reject(fn[n], v, v, z, v, v, 2u, 1.0);
    step_reject(fn[n], v, v, v, z, v, 2u, 1.0);
    step_reject(fn[n], v, v, v, v, z, 2u, 1.0);
    step_reject(fn[n], v, v, v, v, v, 0u, 1.0);
    CHECK_EQ_STATUS(fn[n](v, v, v, v, v, 2u, 1.0, (double *)0), DIANA_ERR_ARG);
    CHECK_EQ_STATUS(fn[n](z, z, z, z, z, 0u, 1.0, out), DIANA_ERR_ARG);
    CHECK(out[0] == SENTINEL && out[1] == SENTINEL);
  }
}

/* With h = 3/4, h * s / 6 = s / 8 is exact for small integer s. */
static void test_step_exact(void) {
  const double y[3] = {1.0, 0.0, -2.0};
  const double k1[3] = {6.0, 0.0, 1.0};
  const double k2[3] = {12.0, 3.0, 2.0};
  const double k3[3] = {0.0, -3.0, 2.0};
  const double k4[3] = {6.0, 6.0, 1.0};
  const double want[3] = {5.5, 0.75, -0.75};
  double ys[DIM], a[DIM], b[DIM], ws[DIM];
  size_t i;

  step_ok(y, k1, k2, k3, k4, 3u, 0.75, want);
  step_ok(y, k1, k2, k3, k4, 1u, 0.75, want);
  for (i = 0; i < DIM; ++i) {
    ys[i] = (double)i - 50.0;
    a[i] = 2.0 * (double)i;
    b[i] = -(double)i;
    ws[i] = ys[i] + 0.5 * (double)i;
  }
  /* k1 = k4 = 2i and k2 = k3 = -i cancel: s = 4i - 4i = 0 */
  step_ok(ys, a, b, b, a, DIM, 0.75, ys);
  for (i = 0; i < DIM; ++i) {
    b[i] = 0.0;
  }
  /* s = 4i and h s / 6 = i / 2 */
  step_ok(ys, a, b, b, a, DIM, 0.75, ws);
}

/* The weights 1, 2, 2, 1 over 6: with h = 6 each unit slope adds its
   weight. */
static void test_step_weight(void) {
  const double y[4] = {0.0, 0.0, 0.0, 0.0};
  const double k1[4] = {1.0, 0.0, 0.0, 0.0};
  const double k2[4] = {0.0, 1.0, 0.0, 0.0};
  const double k3[4] = {0.0, 0.0, 1.0, 0.0};
  const double k4[4] = {0.0, 0.0, 0.0, 1.0};
  const double want[4] = {1.0, 2.0, 2.0, 1.0};

  step_ok(y, k1, k2, k3, k4, 4u, 6.0, want);
}

/* The slope sum is (k1 + k4) + 2 (k2 + k3): with k1 = 1, k4 = 2^-53 and
   k2 = k3 = 2^-54, k1 + k4 rounds to 1 (a tie, to even) and s = 1 + 2^-52;
   6 s rounds to 6 + 2^-49 and dividing by 6 gives 1 + 2^-52. Summing left to
   right gives 1, and the exactly rounded sum gives 1 + 2^-51. */
static void test_step_order(void) {
  const double y[1] = {0.0};
  const double k1[1] = {1.0};
  const double k2[1] = {DBL_EPSILON / 4.0};
  const double k4[1] = {DBL_EPSILON / 2.0};
  const double want[1] = {1.0 + DBL_EPSILON};

  step_ok(y, k1, k2, k2, k4, 1u, 6.0, want);
}

static void test_step_zero_step(void) {
  const double y[3] = {-0.0, 2.0, 0.0};
  const double k[3] = {-3.0, 5.0, -1.0};

  step_ok(y, k, k, k, k, 3u, 0.0, y);
}

/* Underflow is not an error: h * s = 2^-1074 and 2^-1074 / 6 rounds to +0. */
static void test_step_underflow(void) {
  const double y[1] = {0.0};
  const double k[1] = {1.0};
  const double z[1] = {0.0};

  step_ok(y, k, z, z, z, 1u, DBL_TRUE_MIN, y);
}

/* Each case has finite inputs and overflows in one operation: k2 + k3,
   2 (k2 + k3), the slope sum, h * s, or y + h s / 6. */
static void test_step_overflow(void) {
  const double zero[1] = {0.0};
  const double one[1] = {1.0};
  const double max[1] = {DBL_MAX};
  const double half[1] = {DBL_MAX / 2.0};
  const double nmax[1] = {-DBL_MAX};
  const double big[1] = {0x1p1020};

  step_arg(zero, zero, max, max, zero, 1u, 1.0);
  step_arg(zero, zero, max, zero, zero, 1u, 1.0);
  step_arg(zero, max, half, zero, zero, 1u, 1.0);
  step_arg(zero, max, zero, zero, zero, 1u, 2.0);
  /* h * s = 1.5 * 2^1022 is finite, y + 2^1020 is not */
  step_arg(max, big, zero, zero, zero, 1u, 6.0);
  /* k1 + k4 cancels, and DBL_MAX + 1 rounds back to DBL_MAX */
  step_ok(zero, max, zero, zero, nmax, 1u, 1.0, zero);
  step_ok(max, one, zero, zero, zero, 1u, 6.0, max);
}

static void test_step_nonfinite(void) {
  double y[3] = {1.0, 2.0, 3.0};
  double k[4][3] = {
      {4.0, 5.0, 6.0}, {-1.0, 0.5, 2.0}, {7.0, 1.0, -3.0}, {0.25, 8.0, 1.0}};
  size_t i;
  size_t j;

  for (i = 0; i < 3u; ++i) {
    double saved = y[i];
    y[i] = (double)NAN;
    step_arg(y, k[0], k[1], k[2], k[3], 3u, 1.0);
    y[i] = -HUGE_VAL;
    step_arg(y, k[0], k[1], k[2], k[3], 3u, 1.0);
    y[i] = saved;
    for (j = 0; j < 4u; ++j) {
      saved = k[j][i];
      k[j][i] = (double)NAN;
      step_arg(y, k[0], k[1], k[2], k[3], 3u, 1.0);
      k[j][i] = HUGE_VAL;
      step_arg(y, k[0], k[1], k[2], k[3], 3u, 1.0);
      k[j][i] = saved;
    }
  }
  step_arg(y, k[0], k[1], k[2], k[3], 3u, (double)NAN);
  step_arg(y, k[0], k[1], k[2], k[3], 3u, HUGE_VAL);
  step_arg(y, k[0], k[1], k[2], k[3], 3u, -HUGE_VAL);
  {
    const double inf[1] = {HUGE_VAL};
    const double ninf[1] = {-HUGE_VAL};
    const double zero[1] = {0.0};
    /* inf - inf in k1 + k4 and in k2 + k3; 0 * inf */
    step_arg(zero, inf, zero, zero, ninf, 1u, 1.0);
    step_arg(zero, zero, inf, ninf, zero, 1u, 1.0);
    step_arg(zero, inf, zero, zero, zero, 1u, 0.0);
  }
}

static void test_step_failure_keeps_output(void) {
  const double y[3] = {1.0, 2.0, DBL_MAX};
  const double k[3] = {1.0, 1.0, DBL_MAX};
  const double g[3] = {DBL_MAX, 2.0, 3.0};
  const double e[3] = {DBL_MAX, 1.0, 1.0};

  step_arg(y, k, k, k, k, 3u, 1.0);
  step_arg(g, e, e, e, e, 3u, 1.0);
}

/* Inputs the checked stage rejects: the unchecked stage writes the IEEE
   result of each operation, finite components included. */
static void test_stage_unchecked_nonfinite(void) {
  const double zero[1] = {0.0};
  const double one[1] = {1.0};
  const double four[1] = {4.0};
  const double max[1] = {DBL_MAX};
  const double neg[1] = {-DBL_MAX};
  const double inf[1] = {HUGE_VAL};
  const double ninf[1] = {-HUGE_VAL};
  const double nan1[1] = {(double)NAN};
  const double y[3] = {1.0, 2.0, DBL_MAX};
  const double k[3] = {1.0, 1.0, DBL_MAX};
  const double partial[3] = {3.0, 4.0, HUGE_VAL};
  const double g[3] = {-1.0, (double)NAN, 0.5};
  const double e[3] = {2.0, 1.0, -HUGE_VAL};
  const double mixed[3] = {1.0, (double)NAN, -HUGE_VAL};
  const double one3[3] = {1.0, 1.0, 1.0};
  const double nan3[3] = {(double)NAN, (double)NAN, (double)NAN};
  const double inf3[3] = {HUGE_VAL, HUGE_VAL, HUGE_VAL};

  /* overflow in the product (c = h, then c = h/2), then in the sum */
  stage_raw(zero, max, 1u, 2.0, 4, inf);
  stage_raw(zero, four, 1u, DBL_MAX, 2, inf);
  stage_raw(max, max, 1u, 2.0, 3, inf);
  stage_raw(neg, max, 1u, -2.0, 4, ninf);
  /* inf - inf is NaN; 0 * inf is NaN */
  stage_raw(inf, ninf, 1u, 2.0, 2, nan1);
  stage_raw(one, inf, 1u, 0.0, 4, nan1);
  stage_raw(y, k, 3u, 2.0, 4, partial);
  stage_raw(g, e, 3u, 1.0, 4, mixed);
  stage_raw(one3, one3, 3u, (double)NAN, 3, nan3);
  stage_raw(one3, one3, 3u, HUGE_VAL, 2, inf3);
}

/* Inputs the checked step rejects, as for the stage. */
static void test_step_unchecked_nonfinite(void) {
  const double zero[1] = {0.0};
  const double max[1] = {DBL_MAX};
  const double half[1] = {DBL_MAX / 2.0};
  const double nmax[1] = {-DBL_MAX};
  const double big[1] = {0x1p1020};
  const double inf[1] = {HUGE_VAL};
  const double ninf[1] = {-HUGE_VAL};
  const double nan1[1] = {(double)NAN};
  const double y[3] = {1.0, 2.0, DBL_MAX};
  const double k[3] = {1.0, 1.0, DBL_MAX};
  const double partial[3] = {2.0, 3.0, HUGE_VAL};
  const double g[3] = {-1.0, (double)NAN, 0.5};
  const double e[3] = {6.0, 0.0, -HUGE_VAL};
  const double mixed[3] = {5.0, (double)NAN, -HUGE_VAL};
  const double one3[3] = {1.0, 1.0, 1.0};
  const double nan3[3] = {(double)NAN, (double)NAN, (double)NAN};

  /* overflow in k2 + k3, the doubling, the slope sum, h * s, the sum */
  step_raw(zero, zero, max, max, zero, 1u, 1.0, inf);
  step_raw(zero, zero, max, zero, zero, 1u, 1.0, inf);
  step_raw(zero, max, half, zero, zero, 1u, 1.0, inf);
  step_raw(zero, max, zero, zero, zero, 1u, 2.0, inf);
  step_raw(max, big, zero, zero, zero, 1u, 6.0, inf);
  step_raw(zero, nmax, zero, zero, zero, 1u, 2.0, ninf);
  /* inf - inf in k1 + k4 and in k2 + k3; 0 * inf */
  step_raw(zero, inf, zero, zero, ninf, 1u, 1.0, nan1);
  step_raw(zero, zero, inf, ninf, zero, 1u, 1.0, nan1);
  step_raw(zero, inf, zero, zero, zero, 1u, 0.0, nan1);
  step_raw(y, k, k, k, k, 3u, 1.0, partial);
  step_raw(g, e, e, e, e, 3u, 1.0, mixed);
  step_raw(one3, one3, one3, one3, one3, 3u, (double)NAN, nan3);
}

/* Callback wrapper. Each right-hand side below keeps every stage and iterate
   exactly representable, so the expected states are exact. */

struct record {
  unsigned calls;
  double t[16];
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
  if (rec->calls < 16u) {
    rec->t[rec->calls] = t;
  }
  dy[0] = rec->calls >= rec->fail_at ? HUGE_VAL : t;
  rec->calls++;
}

static void test_wrapper_integrate(void) {
  double y[2] = {64.0, -8.0};
  double w[10];
  double r[2] = {1.0, 0.0};
  double z[1] = {0.0};
  struct record rec = {0u, {0.0}, 100u, (void *)0};
  const double times[8] = {1.0, 1.125, 1.125, 1.25, 1.25, 1.375, 1.375, 1.5};
  unsigned done = 99u;
  unsigned i;

  /* y' = -y with h = 1: the stages are y, y/2, 3y/4, y/4 and the step
     multiplies by 1 - 1 + 1/2 - 1/6 + 1/24 = 3/8 */
  CHECK_EQ_STATUS(diana_rk4(decay, (void *)0, 0.0, 1.0, 3u, y, 2u, w, &done),
                  DIANA_OK);
  CHECK(done == 3u);
  CHECK(y[0] == 3.375 && y[1] == -0.421875);

  /* y' = (y2, -y1) with h = 6: the step is 37 I - 30 A for the rotation A,
     (1, 0) -> (37, 30) -> (469, 2220) */
  CHECK_EQ_STATUS(
      diana_rk4(rotation, (void *)0, 0.0, 6.0, 1u, r, 2u, w, (unsigned *)0),
      DIANA_OK);
  CHECK(r[0] == 37.0 && r[1] == 30.0);
  CHECK_EQ_STATUS(
      diana_rk4(rotation, (void *)0, 6.0, 6.0, 1u, r, 2u, w, (unsigned *)0),
      DIANA_OK);
  CHECK(r[0] == 469.0 && r[1] == 2220.0);

  /* y' = t from t0 = 1 with h = 1/4: the slopes are taken at t, t + h/2
     (twice) and t + h, and RK4 integrates t exactly to (1.5^2 - 1) / 2 */
  CHECK_EQ_STATUS(diana_rk4(ramp, &rec, 1.0, 0.25, 2u, z, 1u, w, &done),
                  DIANA_OK);
  CHECK(done == 2u && rec.calls == 8u && rec.self == (void *)&rec);
  for (i = 0; i < 8u; ++i) {
    CHECK(rec.t[i] == times[i]);
  }
  CHECK(z[0] == 0.625);
}

static void test_wrapper_no_step(void) {
  double y[1] = {2.0};
  double w[5];
  struct record rec = {0u, {0.0}, 100u, (void *)0};
  unsigned done = 99u;

  CHECK_EQ_STATUS(diana_rk4(ramp, &rec, 0.0, 1.0, 0u, y, 1u, w, &done),
                  DIANA_OK);
  CHECK(done == 0u && rec.calls == 0u && y[0] == 2.0);
}

static void test_wrapper_argument(void) {
  double y[1] = {2.0};
  double w[5];
  struct record rec = {0u, {0.0}, 100u, (void *)0};
  unsigned done = 99u;

  CHECK_EQ_STATUS(
      diana_rk4((diana_ode_fn)0, &rec, 0.0, 1.0, 1u, y, 1u, w, &done),
      DIANA_ERR_ARG);
  CHECK(done == 0u);
  CHECK_EQ_STATUS(
      diana_rk4(ramp, &rec, 0.0, 1.0, 1u, (double *)0, 1u, w, &done),
      DIANA_ERR_ARG);
  CHECK_EQ_STATUS(
      diana_rk4(ramp, &rec, 0.0, 1.0, 1u, y, 1u, (double *)0, &done),
      DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_rk4(ramp, &rec, 0.0, 1.0, 1u, y, 0u, w, &done),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(
      diana_rk4((diana_ode_fn)0, &rec, 0.0, 1.0, 1u, y, 1u, w, (unsigned *)0),
      DIANA_ERR_ARG);
  CHECK(rec.calls == 0u && y[0] == 2.0);
}

/* A failing stage or step leaves y at the last good state and done at the
   number of completed steps. */
static void test_wrapper_failure(void) {
  double z[1] = {0.0};
  double w[5];
  double big[1] = {DBL_MAX / 2.0};
  unsigned done = 99u;
  unsigned fail;

  /* y' = t from t0 = 0, h = 1: an infinite k1, k2 or k3 fails the stage that
     uses it, an infinite k4 fails the step */
  for (fail = 0u; fail < 4u; ++fail) {
    struct record rec = {0u, {0.0}, 0u, (void *)0};
    rec.fail_at = fail;
    z[0] = 0.0;
    CHECK_EQ_STATUS(diana_rk4(ramp, &rec, 0.0, 1.0, 5u, z, 1u, w, &done),
                    DIANA_ERR_ARG);
    CHECK(done == 0u && rec.calls == fail + 1u && z[0] == 0.0);
  }
  {
    /* the first step reaches y(1) = 1/2, the second fails at k2 */
    struct record rec = {0u, {0.0}, 5u, (void *)0};
    z[0] = 0.0;
    CHECK_EQ_STATUS(diana_rk4(ramp, &rec, 0.0, 1.0, 5u, z, 1u, w, &done),
                    DIANA_ERR_ARG);
    CHECK(done == 1u && rec.calls == 6u && z[0] == 0.5);
  }

  /* y' = -y with h = -2 from DBL_MAX/2: Y2 = 2y = DBL_MAX, and
     Y3 = y + DBL_MAX overflows */
  CHECK_EQ_STATUS(diana_rk4(decay, (void *)0, 0.0, -2.0, 3u, big, 1u, w, &done),
                  DIANA_ERR_ARG);
  CHECK(done == 0u && big[0] == DBL_MAX / 2.0);
}

int main(void) {
  test_stage_argument();
  test_stage_exact();
  test_stage_no_contraction();
  test_stage_coefficient();
  test_stage_zero_step();
  test_stage_overflow();
  test_stage_nonfinite();
  test_stage_failure_keeps_output();
  test_step_argument();
  test_step_exact();
  test_step_weight();
  test_step_order();
  test_step_zero_step();
  test_step_underflow();
  test_step_overflow();
  test_step_nonfinite();
  test_step_failure_keeps_output();
  test_stage_unchecked_nonfinite();
  test_step_unchecked_nonfinite();
  test_wrapper_integrate();
  test_wrapper_no_step();
  test_wrapper_argument();
  test_wrapper_failure();
  return check_report("rk4");
}
