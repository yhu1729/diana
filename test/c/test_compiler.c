#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "diana/diana.h"

#define CAPACITY 41u
#define STEP_LIMIT 4096u
#define RANDOM_ARRAY 200u
#define RANDOM_RUN 96u
#define SENTINEL 42.0

#define SIGN_BIT UINT64_C(0x8000000000000000)
#define MANTISSA_MASK UINT64_C(0x000fffffffffffff)
#define FNV_OFFSET UINT64_C(0xcbf29ce484222325)
#define FNV_PRIME UINT64_C(0x00000100000001b3)

#define VAL_INF from_bits(UINT64_C(0x7ff0000000000000))
#define VAL_QNAN from_bits(UINT64_C(0x7ff8000000000000))
#define VAL_SNAN from_bits(UINT64_C(0x7ff0000000000001))
#define VAL_TRUE_MIN 0x1p-1074
#define VAL_NORM_MIN 0x1p-1022
#define VAL_HALF_MAX 0x1.fffffffffffffp1022
#define VAL_MAX 0x1.fffffffffffffp1023

static const uint64_t special_bits[] = {
    UINT64_C(0x0000000000000000), UINT64_C(0x8000000000000000),
    UINT64_C(0x7ff0000000000000), UINT64_C(0xfff0000000000000),
    UINT64_C(0x7ff8000000000000), UINT64_C(0xfff8000000000000),
    UINT64_C(0x7ff0000000000001), UINT64_C(0x0000000000000001),
    UINT64_C(0x8000000000000001), UINT64_C(0x000fffffffffffff),
    UINT64_C(0x800fffffffffffff), UINT64_C(0x0010000000000000),
    UINT64_C(0x8010000000000000), UINT64_C(0x7fdfffffffffffff),
    UINT64_C(0xffdfffffffffffff), UINT64_C(0x7fefffffffffffff),
    UINT64_C(0xffefffffffffffff), UINT64_C(0x3ff0000000000000),
    UINT64_C(0xbff0000000000000), UINT64_C(0x3cb0000000000000)};

static uint64_t rng = UINT64_C(0x2545f4914f6cdd1d);
static unsigned case_count = 0u;

static double from_bits(uint64_t u) {
  double d;
  memcpy(&d, &u, sizeof d);
  return d;
}

static uint64_t to_bits(double d) {
  uint64_t u;
  memcpy(&u, &d, sizeof u);
  return u;
}

static uint64_t rng_next(void) {
  uint64_t z;
  rng += UINT64_C(0x9e3779b97f4a7c15);
  z = rng;
  z = (z ^ (z >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
  z = (z ^ (z >> 27)) * UINT64_C(0x94d049bb133111eb);
  return z ^ (z >> 31);
}

static unsigned rng_below(unsigned n) {
  return (unsigned)(rng_next() % (uint64_t)n);
}

static double compose(uint64_t sign, unsigned exponent, uint64_t mantissa) {
  return from_bits(((sign & 1u) << 63) | ((uint64_t)exponent << 52) |
                   (mantissa & MANTISSA_MASK));
}

static double random_value(int mixed) {
  uint64_t sign = rng_next();
  uint64_t mantissa = rng_next();
  unsigned kind = mixed ? rng_below(64u) : 14u + rng_below(50u);

  if (kind < 2u) {
    return from_bits(special_bits[rng_below(
        (unsigned)(sizeof special_bits / sizeof special_bits[0]))]);
  }
  if (kind < 6u) {
    return compose(sign, 0u, mantissa);
  }
  if (kind < 8u) {
    return compose(sign, 1u + rng_below(8u), mantissa);
  }
  if (kind < 10u) {
    return compose(sign, 2038u + rng_below(9u), mantissa);
  }
  if (kind < 14u) {
    return compose(sign, 1u + rng_below(2046u), mantissa);
  }
  if (kind < 40u) {
    return compose(sign, 1003u + rng_below(41u), mantissa);
  }
  return compose(sign, 1019u + rng_below(9u),
                 mantissa & (UINT64_C(0x3f) << 46));
}

static int bounded(double v) {
  return (to_bits(v) & ~SIGN_BIT) <= to_bits(VAL_HALF_MAX);
}

static double random_bounded(int mixed) {
  double v = random_value(mixed);
  while (!bounded(v)) {
    v = random_value(mixed);
  }
  return v;
}

static uint64_t mix(uint64_t h, uint64_t v) {
  unsigned i;
  for (i = 0u; i < 8u; ++i) {
    h ^= (v >> (8u * i)) & 0xffu;
    h *= FNV_PRIME;
  }
  return h;
}

static void put_head(const char *kernel, const char *label) {
  printf("%s %u %s", kernel, case_count, label);
  ++case_count;
}

static void put_double(double d) {
  printf(" %016llx", (unsigned long long)to_bits(d));
}

static void put_status(diana_status st) { printf(" s%08x", (unsigned)st); }

static void put_array(const double *y, size_t n) {
  size_t i;
  printf(" [");
  for (i = 0u; i < n; ++i) {
    put_double(y[i]);
  }
  printf(" ]");
}

static void put_state(const diana_bisection_state *s) {
  put_double(s->a);
  put_double(s->b);
  put_double(s->fa);
  put_double(s->fb);
  put_double(s->x);
  put_double(s->tol);
  printf(" %08x %08x", s->iter, s->max_iter);
}

static uint64_t mix_state(uint64_t h, diana_status st,
                          const diana_bisection_state *s) {
  h = mix(h, (uint64_t)(unsigned)st);
  h = mix(h, to_bits(s->a));
  h = mix(h, to_bits(s->b));
  h = mix(h, to_bits(s->fa));
  h = mix(h, to_bits(s->fb));
  h = mix(h, to_bits(s->x));
  h = mix(h, to_bits(s->tol));
  h = mix(h, (uint64_t)s->iter);
  return mix(h, (uint64_t)s->max_iter);
}

static void set_sentinel(diana_bisection_state *s) {
  s->a = -7.0;
  s->b = 7.0;
  s->fa = -1.0;
  s->fb = 1.0;
  s->x = 0.25;
  s->tol = 0.125;
  s->iter = 3u;
  s->max_iter = 9u;
}

typedef double (*bisection_fn)(double x, double c);

static double f_linear(double x, double c) { return x - c; }

static double f_reverse(double x, double c) { return c - x; }

static double f_square(double x, double c) { return x * x - c; }

static double f_sign(double x, double c) {
  if (x < c) {
    return -1.0;
  }
  return x > c ? 1.0 : -0.0;
}

static void bisection_init_case(const char *label, double a, double b,
                                double fa, double fb, double tol,
                                unsigned max_iter) {
  diana_bisection_state s;
  diana_status st;

  set_sentinel(&s);
  st = diana_bisection_init(&s, a, b, fa, fb, tol, max_iter);
  put_head("bisection_init", label);
  put_double(a);
  put_double(b);
  put_double(fa);
  put_double(fb);
  put_double(tol);
  printf(" %08x", max_iter);
  put_status(st);
  put_state(&s);
  printf("\n");
}

static void bisection_run(const char *label, bisection_fn f, double c, double a,
                          double b, double tol, unsigned max_iter,
                          int verbose) {
  diana_bisection_state s;
  diana_status st;
  diana_status rst;
  double root = SENTINEL;
  double width = SENTINEL;
  uint64_t digest = FNV_OFFSET;
  unsigned steps = 0u;

  set_sentinel(&s);
  st = diana_bisection_init(&s, a, b, f(a, c), f(b, c), tol, max_iter);
  put_head("bisection_run", label);
  put_double(c);
  put_double(a);
  put_double(b);
  put_double(tol);
  printf(" %08x", max_iter);
  put_status(st);
  put_state(&s);
  printf("\n");
  while (st == DIANA_CONTINUE && steps < STEP_LIMIT) {
    st = diana_bisection_step(&s, f(s.x, c));
    ++steps;
    if (verbose) {
      printf("  step %u", steps);
      put_status(st);
      put_state(&s);
      printf("\n");
    } else {
      digest = mix_state(digest, st, &s);
    }
  }
  if (st == DIANA_ERR_MAXITER) {
    st = diana_bisection_step(&s, f(s.x, c));
    printf("  again");
    put_status(st);
    put_state(&s);
    printf("\n");
  }
  rst = diana_bisection_result(&s, &root, &width);
  printf("  end %u %016llx", steps, (unsigned long long)digest);
  put_status(st);
  put_state(&s);
  put_status(rst);
  put_double(root);
  put_double(width);
  printf("\n");
}

static void bisection_step_case(const char *label, double fx) {
  diana_bisection_state s;
  diana_status st;

  set_sentinel(&s);
  st = diana_bisection_init(&s, 0.0, 2.0, -2.0, 2.0, 0.0, 100u);
  put_head("bisection_step", label);
  put_status(st);
  st = diana_bisection_step(&s, -0.75);
  put_status(st);
  st = diana_bisection_step(&s, fx);
  put_double(fx);
  put_status(st);
  put_state(&s);
  printf("\n");
}

static void bisection_result_case(const char *label, int want_root,
                                  int want_width) {
  diana_bisection_state s;
  double root = SENTINEL;
  double width = SENTINEL;
  diana_status st;

  set_sentinel(&s);
  st = diana_bisection_result(&s, want_root ? &root : (double *)0,
                              want_width ? &width : (double *)0);
  put_head("bisection_result", label);
  put_status(st);
  put_double(root);
  put_double(width);
  printf("\n");
}

static void test_bisection(void) {
  const double inf = VAL_INF;
  const double nan = VAL_QNAN;
  const double half_max = VAL_HALF_MAX;
  const double tiny = VAL_TRUE_MIN;
  const double past = from_bits(to_bits(half_max) + 1u);
  diana_status st;
  unsigned k;

  st = diana_bisection_init((diana_bisection_state *)0, 0.0, 1.0, -1.0, 1.0,
                            0.0, 10u);
  put_head("bisection_init", "null");
  put_status(st);
  printf("\n");
  bisection_init_case("nan_a", nan, 1.0, -1.0, 1.0, 0.0, 10u);
  bisection_init_case("nan_b", 0.0, nan, -1.0, 1.0, 0.0, 10u);
  bisection_init_case("nan_fa", 0.0, 1.0, nan, 1.0, 0.0, 10u);
  bisection_init_case("nan_fb", 0.0, 1.0, -1.0, nan, 0.0, 10u);
  bisection_init_case("nan_tol", 0.0, 1.0, -1.0, 1.0, nan, 10u);
  bisection_init_case("snan_fa", 0.0, 1.0, VAL_SNAN, 1.0, 0.0, 10u);
  bisection_init_case("inf_a", -inf, 1.0, -1.0, 1.0, 0.0, 10u);
  bisection_init_case("inf_b", 0.0, inf, -1.0, 1.0, 0.0, 10u);
  bisection_init_case("inf_fa", 0.0, 1.0, -inf, 1.0, 0.0, 10u);
  bisection_init_case("inf_fb", 0.0, 1.0, -1.0, inf, 0.0, 10u);
  bisection_init_case("inf_tol", 0.0, 1.0, -1.0, 1.0, inf, 10u);
  bisection_init_case("reversed", 1.0, 0.0, -1.0, 1.0, 0.0, 10u);
  bisection_init_case("negative_tol", 0.0, 1.0, -1.0, 1.0, -tiny, 10u);
  bisection_init_case("zero_iter", 0.0, 1.0, -1.0, 1.0, 0.0, 0u);
  bisection_init_case("past_a", -past, 0.0, -1.0, 1.0, 0.0, 10u);
  bisection_init_case("past_b", 0.0, past, -1.0, 1.0, 0.0, 10u);
  bisection_init_case("max_b", 0.0, VAL_MAX, -1.0, 1.0, 0.0, 10u);
  bisection_init_case("same_positive", 0.0, 1.0, tiny, VAL_MAX, 0.0, 10u);
  bisection_init_case("same_negative", 0.0, 1.0, -1.0, -tiny, 0.0, 10u);
  bisection_init_case("limit", -half_max, half_max, -1.0, 1.0, 0.0, 10u);
  bisection_init_case("negative_zero_tol", 0.0, 1.0, -1.0, 1.0, -0.0, 10u);
  bisection_init_case("fa_zero", 0.0, 1.0, 0.0, 1.0, 0.0, 10u);
  bisection_init_case("fa_negative_zero", 0.0, 1.0, -0.0, 1.0, 0.0, 10u);
  bisection_init_case("fb_zero", 0.0, 1.0, -1.0, 0.0, 0.0, 10u);
  bisection_init_case("fb_negative_zero", 0.0, 1.0, 1.0, -0.0, 0.0, 10u);
  bisection_init_case("both_zero", 0.0, 1.0, -0.0, 0.0, 0.0, 10u);
  bisection_init_case("tol_wide", 0.0, 1.0, -1.0, 1.0, 2.0, 10u);
  bisection_init_case("tol_equal", 0.0, 1.0, -1.0, 1.0, 1.0, 10u);
  bisection_init_case("point", 3.0, 3.0, -1.0, 1.0, 0.0, 10u);
  bisection_init_case("adjacent_up", from_bits(UINT64_C(0x3ff0000000000001)),
                      from_bits(UINT64_C(0x3ff0000000000002)), -1.0, 1.0, 0.0,
                      10u);
  bisection_init_case("adjacent_down", from_bits(UINT64_C(0x3feffffffffffffe)),
                      from_bits(UINT64_C(0x3fefffffffffffff)), -1.0, 1.0, 0.0,
                      10u);
  bisection_init_case("adjacent_binade",
                      from_bits(UINT64_C(0x3fefffffffffffff)), 1.0, -1.0, 1.0,
                      0.0, 10u);
  bisection_init_case("adjacent_subnormal", tiny, 2.0 * tiny, -1.0, 1.0, 0.0,
                      10u);
  bisection_init_case("adjacent_zero", -tiny, 0.0, -1.0, 1.0, 0.0, 10u);
  bisection_init_case("continue", 0.0, 1.0, -1.0, 1.0, 0.0, 10u);

  bisection_run("exact_half", f_linear, 0.5, 0.0, 1.0, 0.0, 100u, 1);
  bisection_run("sqrt2_tol", f_square, 2.0, 0.0, 2.0, 1e-12, 100u, 1);
  bisection_run("sqrt2", f_square, 2.0, 0.0, 2.0, 0.0, 2100u, 1);
  bisection_run("tenth", f_linear, 0.1, 0.0, 1.0, 0.0, 2100u, 1);
  bisection_run("tenth_reverse", f_reverse, 0.1, 0.0, 1.0, 0.0, 2100u, 1);
  bisection_run("sign_zero", f_sign, 0.5, 0.0, 1.0, 0.0, 100u, 1);
  bisection_run("sign_third", f_sign, 1.0 / 3.0, 0.0, 1.0, 0.0, 2100u, 1);
  bisection_run("worst_case", f_linear, tiny, -half_max, half_max, 0.0, 2100u,
                1);
  bisection_run("worst_case_mirror", f_linear, -tiny, -half_max, half_max, 0.0,
                2100u, 1);
  bisection_run("large_root", f_linear, 1e300, -half_max, half_max, 0.0, 2100u,
                1);
  bisection_run("subnormal", f_linear, tiny, -5.0 * tiny, 7.0 * tiny, 0.0,
                2100u, 1);
  bisection_run("subnormal_wide", f_reverse, 3.0 * tiny, -VAL_NORM_MIN,
                VAL_NORM_MIN, 0.0, 2100u, 1);
  bisection_run("max_iter", f_square, 2.0, 0.0, 2.0, 0.0, 5u, 1);
  bisection_run("max_iter_one", f_linear, 0.3, 0.0, 1.0, 0.0, 1u, 1);
  bisection_run("square_overflow", f_square, 1.0, -half_max, half_max, 0.0,
                2100u, 1);

  bisection_step_case("nan", VAL_QNAN);
  bisection_step_case("snan", VAL_SNAN);
  bisection_step_case("inf", inf);
  bisection_step_case("negative_inf", -inf);
  bisection_step_case("zero", 0.0);
  bisection_step_case("negative_zero", -0.0);
  bisection_step_case("tiny", tiny);
  bisection_step_case("negative_tiny", -tiny);
  st = diana_bisection_step((diana_bisection_state *)0, 1.0);
  put_head("bisection_step", "null");
  put_status(st);
  printf("\n");

  st = diana_bisection_result((const diana_bisection_state *)0, (double *)0,
                              (double *)0);
  put_head("bisection_result", "null");
  put_status(st);
  printf("\n");
  bisection_result_case("both", 1, 1);
  bisection_result_case("root", 1, 0);
  bisection_result_case("width", 0, 1);
  bisection_result_case("neither", 0, 0);

  for (k = 0u; k < RANDOM_RUN; ++k) {
    double v[3];
    double t;
    double tol = 0.0;
    unsigned max_iter = 2100u;
    bisection_fn f = f_linear;
    int mixed = (int)(k % 2u);

    v[0] = random_bounded(mixed);
    v[1] = random_bounded(mixed);
    v[2] = random_bounded(mixed);
    if (v[0] > v[1]) {
      t = v[0];
      v[0] = v[1];
      v[1] = t;
    }
    if (v[1] > v[2]) {
      t = v[1];
      v[1] = v[2];
      v[2] = t;
    }
    if (v[0] > v[1]) {
      t = v[0];
      v[0] = v[1];
      v[1] = t;
    }
    switch (rng_below(4u)) {
    case 0u:
      f = f_reverse;
      break;
    case 1u:
      f = f_square;
      v[1] = v[1] * v[1];
      break;
    default:
      break;
    }
    if (rng_below(2u) == 0u) {
      tol = from_bits(to_bits(random_bounded(mixed)) & ~SIGN_BIT);
    }
    if (rng_below(8u) == 0u) {
      max_iter = 1u + rng_below(60u);
    }
    bisection_run("random", f, v[1], v[0], v[2], tol, max_iter, 0);
  }
}

static void trapezoidal_case(const char *label, const double *y, size_t n,
                             double h) {
  double r = SENTINEL;
  diana_status st = diana_trapezoidal(y, n, h, &r);
  put_head("trapezoidal", label);
  put_double(h);
  put_array(y, y == (const double *)0 ? 0u : n);
  put_status(st);
  put_double(r);
  printf("\n");
}

static void simpson_case(const char *label, const double *y, size_t n,
                         double h) {
  double r = SENTINEL;
  diana_status st = diana_simpson(y, n, h, &r);
  put_head("simpson", label);
  put_double(h);
  put_array(y, y == (const double *)0 ? 0u : n);
  put_status(st);
  put_double(r);
  printf("\n");
}

static void quadrature_case(int simpson, const char *label, const double *y,
                            size_t n, double h) {
  if (simpson) {
    simpson_case(label, y, n, h);
  } else {
    trapezoidal_case(label, y, n, h);
  }
}

static void test_quadrature_common(int simpson) {
  static const double one[5] = {1.0, 1.0, 1.0, 1.0, 1.0};
  static const double ramp[5] = {1.0, 3.0, 5.0, 7.0, 9.0};
  static const double negative[5] = {-1.0, -3.0, -5.0, -7.0, -9.0};
  static const double zero[5] = {0.0, 0.0, 0.0, 0.0, 0.0};
  static const double negative_zero[5] = {-0.0, -0.0, -0.0, -0.0, -0.0};
  static const double mixed_zero[5] = {-0.0, 0.0, -0.0, 0.0, -0.0};
  static const double subnormal[5] = {VAL_TRUE_MIN, 0.0, 0.0, 0.0, 0.0};
  static const double subnormal_three[5] = {0x1.8p-1073, 0.0, 0.0, 0.0, 0.0};
  static const double subnormal_mid[5] = {0.0, VAL_TRUE_MIN, 0.0, VAL_TRUE_MIN,
                                          0.0};
  static const double subnormal_max[5] = {VAL_NORM_MIN, -VAL_TRUE_MIN, 0.0,
                                          VAL_TRUE_MIN, -VAL_NORM_MIN};
  static const double big[5] = {VAL_MAX, VAL_MAX, VAL_MAX, VAL_MAX, VAL_MAX};
  static const double big_end[5] = {VAL_MAX, 0.0, 0.0, 0.0, VAL_MAX};
  static const double big_mid[5] = {0.0, VAL_MAX, 0.0, VAL_MAX, 0.0};
  static const double big_even[5] = {0.0, 0.0, VAL_MAX, 0.0, 0.0};
  static const double half_max[5] = {VAL_HALF_MAX, 0.0, 0.0, 0.0, 0.0};
  static const double cancel[5] = {VAL_MAX, -VAL_MAX, VAL_MAX, -VAL_MAX,
                                   VAL_MAX};
  static const double third[5] = {0.1, 0.2, 0.3, 0.4, 0.5};
  static double y[5];
  size_t i;
  size_t n;

  quadrature_case(simpson, "null", (const double *)0, 3u, 1.0);
  quadrature_case(simpson, "null_empty", (const double *)0, 0u, 1.0);
  for (n = 0u; n <= 5u; ++n) {
    quadrature_case(simpson, "length", ramp, n, 1.0);
  }
  quadrature_case(simpson, "one", one, 5u, 0.25);
  quadrature_case(simpson, "ramp_half", ramp, 5u, 0.5);
  quadrature_case(simpson, "ramp_third", ramp, 5u, 1.0 / 3.0);
  quadrature_case(simpson, "negative", negative, 5u, 0.75);
  quadrature_case(simpson, "third", third, 5u, 0.1);
  quadrature_case(simpson, "h_zero", ramp, 5u, 0.0);
  quadrature_case(simpson, "h_negative_zero", ramp, 5u, -0.0);
  quadrature_case(simpson, "h_zero_negative", negative, 5u, 0.0);
  quadrature_case(simpson, "zero", zero, 5u, 1.0);
  quadrature_case(simpson, "zero_negative_h", zero, 5u, -1.0);
  quadrature_case(simpson, "negative_zero", negative_zero, 5u, 1.0);
  quadrature_case(simpson, "negative_zero_3", negative_zero, 3u, 1.0);
  quadrature_case(simpson, "negative_zero_2", negative_zero, 2u, 1.0);
  quadrature_case(simpson, "mixed_zero", mixed_zero, 5u, 1.0);
  quadrature_case(simpson, "subnormal", subnormal, 5u, 1.0);
  quadrature_case(simpson, "subnormal_2", subnormal, 2u, 1.0);
  quadrature_case(simpson, "subnormal_3", subnormal, 3u, 1.0);
  quadrature_case(simpson, "subnormal_three", subnormal_three, 3u, 1.0);
  quadrature_case(simpson, "subnormal_three_2", subnormal_three, 2u, 1.0);
  quadrature_case(simpson, "subnormal_mid", subnormal_mid, 5u, 1.0);
  quadrature_case(simpson, "subnormal_max", subnormal_max, 5u, 1.0);
  quadrature_case(simpson, "subnormal_h", one, 5u, VAL_TRUE_MIN);
  quadrature_case(simpson, "subnormal_h_third", one, 3u, 0x1.8p-1073);
  quadrature_case(simpson, "underflow_h", ramp, 5u, 0x1p-1060);
  quadrature_case(simpson, "big", big, 5u, 1.0);
  quadrature_case(simpson, "big_2", big, 2u, 0.5);
  quadrature_case(simpson, "big_end", big_end, 5u, 1.0);
  quadrature_case(simpson, "big_end_2", big_end, 3u, 0.25);
  quadrature_case(simpson, "big_mid", big_mid, 5u, 0.25);
  quadrature_case(simpson, "big_mid_3", big_mid, 3u, 0.25);
  quadrature_case(simpson, "big_even", big_even, 5u, 1.0);
  quadrature_case(simpson, "big_even_small", big_even, 5u, 0.25);
  quadrature_case(simpson, "big_h_zero", big, 5u, 0.0);
  quadrature_case(simpson, "half_max", half_max, 3u, 1.0);
  quadrature_case(simpson, "half_max_h", one, 3u, VAL_HALF_MAX);
  quadrature_case(simpson, "max_h", one, 5u, VAL_MAX);
  quadrature_case(simpson, "quarter_max_h", one, 3u, 0x1p1022);
  quadrature_case(simpson, "cancel", cancel, 5u, 1.0);
  quadrature_case(simpson, "cancel_3", cancel, 3u, 1.0);
  quadrature_case(simpson, "h_nan", ramp, 5u, VAL_QNAN);
  quadrature_case(simpson, "h_snan", ramp, 5u, VAL_SNAN);
  quadrature_case(simpson, "h_inf", ramp, 5u, VAL_INF);
  quadrature_case(simpson, "h_negative_inf", ramp, 5u, -VAL_INF);
  quadrature_case(simpson, "h_inf_zero", zero, 5u, VAL_INF);
  for (i = 0u; i < 5u; ++i) {
    memcpy(y, ramp, sizeof y);
    y[i] = VAL_QNAN;
    quadrature_case(simpson, "nan", y, 5u, 1.0);
    y[i] = VAL_SNAN;
    quadrature_case(simpson, "snan", y, 5u, 1.0);
    y[i] = VAL_INF;
    quadrature_case(simpson, "inf", y, 5u, 1.0);
    y[i] = -VAL_INF;
    quadrature_case(simpson, "negative_inf", y, 5u, 0.0);
    y[4u - i] = VAL_INF;
    quadrature_case(simpson, "both_inf", y, 5u, 1.0);
  }
}

static void test_quadrature_random(int simpson) {
  static double y[CAPACITY];
  unsigned k;
  size_t i;

  for (k = 0u; k < RANDOM_ARRAY; ++k) {
    int mixed = (int)(k % 2u);
    size_t n = simpson ? 3u + 2u * (size_t)rng_below(CAPACITY / 2u - 1u)
                       : 2u + (size_t)rng_below(CAPACITY - 1u);
    double h = random_value(mixed);
    for (i = 0u; i < n; ++i) {
      y[i] = random_value(mixed);
    }
    quadrature_case(simpson, "random", y, n, h);
  }
}

static void test_trapezoidal(void) {
  static const double tie[4] = {0x1p53, 1.0, 1.0, 0x1p53};
  static const double big[3] = {VAL_HALF_MAX, VAL_HALF_MAX, 0.0};
  static const double product[2] = {VAL_MAX, 0.0};
  static double y[1001];
  double r = SENTINEL;
  diana_status st;
  size_t i;

  st = diana_trapezoidal(tie, 4u, 1.0, (double *)0);
  put_head("trapezoidal", "null_result");
  put_status(st);
  printf("\n");
  test_quadrature_common(0);
  trapezoidal_case("tie", tie, 4u, 1.0);
  trapezoidal_case("interior", big, 3u, 1.0);
  trapezoidal_case("product", product, 2u, 2.0);
  trapezoidal_case("product_over", product, 2u, 4.0);
  for (i = 0u; i < 1001u; ++i) {
    y[i] = 3.0 * (double)i - 1000.0;
  }
  st = diana_trapezoidal(y, 1001u, 0x1p-7, &r);
  put_head("trapezoidal", "affine_1001");
  put_status(st);
  put_double(r);
  printf("\n");
  test_quadrature_random(0);
}

static void test_simpson(void) {
  static const double order[5] = {0x1p53, 0.5, 0.25, 0.5, -0x1p53};
  static const double odd_tie[7] = {0.0, 0x1p53, 0.0, 1.0, 0.0, -0x1p53, 0.0};
  static const double even_tie[9] = {0.0, 0.0,     0x1p53, 0.0, 1.0,
                                     0.0, -0x1p53, 0.0,    0.0};
  static const double quarter[3] = {0.0, 0x1p1021, 0.0};
  static double y[1001];
  double r = SENTINEL;
  diana_status st;
  size_t i;

  st = diana_simpson(order, 5u, 1.0, (double *)0);
  put_head("simpson", "null_result");
  put_status(st);
  printf("\n");
  test_quadrature_common(1);
  simpson_case("order", order, 5u, 1.0);
  simpson_case("odd_tie", odd_tie, 7u, 1.0);
  simpson_case("even_tie", even_tie, 9u, 1.0);
  simpson_case("quarter", quarter, 3u, 0.25);
  simpson_case("quarter_over", quarter, 3u, 1.0);
  for (i = 0u; i < 1001u; ++i) {
    double x = (double)i - 400.0;
    y[i] = x * x * x + 7.0;
  }
  st = diana_simpson(y, 1001u, 0.125, &r);
  put_head("simpson", "cubic_1001");
  put_status(st);
  put_double(r);
  printf("\n");
  test_quadrature_random(1);
}

static void euler_case(const char *label, const double *y, const double *f,
                       size_t d, double h) {
  static double out[CAPACITY];
  size_t i;
  diana_status st;

  for (i = 0u; i < CAPACITY; ++i) {
    out[i] = SENTINEL;
  }
  st = diana_euler_step(y, f, d, h, out);
  put_head("euler", label);
  put_double(h);
  put_array(y, y == (const double *)0 ? 0u : d);
  put_array(f, f == (const double *)0 ? 0u : d);
  put_status(st);
  put_array(out, d < CAPACITY ? d : CAPACITY);
  printf("\n");
}

static void test_euler(void) {
  static const double y4[4] = {1.0, -2.0, 0.5, 0.0};
  static const double f4[4] = {0.5, 0.25, -1.0, 3.0};
  static const double fma_y[1] = {-1.0};
  static const double fma_f[1] = {0x1.ffffffffffffep-1};
  static const double zeros[4] = {0.0, -0.0, 0.0, -0.0};
  static const double signed_zero[4] = {-0.0, -0.0, 0.0, 0.0};
  static const double tiny_f[1] = {VAL_TRUE_MIN};
  static const double zero1[1] = {0.0};
  static const double one1[1] = {1.0};
  static const double max1[1] = {VAL_MAX};
  static const double neg_max1[1] = {-VAL_MAX};
  static const double fail_last_y[3] = {1.0, 2.0, VAL_MAX};
  static const double fail_last_f[3] = {1.0, 1.0, VAL_MAX};
  static const double fail_first_f[3] = {VAL_MAX, 2.0, 3.0};
  static const double fail_first_y[3] = {VAL_MAX, 1.0, 1.0};
  static double y[CAPACITY];
  static double f[CAPACITY];
  static double out[1] = {SENTINEL};
  diana_status st;
  unsigned k;
  size_t i;

  euler_case("null_y", (const double *)0, f4, 4u, 1.0);
  euler_case("null_f", y4, (const double *)0, 4u, 1.0);
  st = diana_euler_step(y4, f4, 4u, 1.0, (double *)0);
  put_head("euler", "null_out");
  put_status(st);
  printf("\n");
  euler_case("empty", y4, f4, 0u, 1.0);
  st = diana_euler_step((const double *)0, (const double *)0, 0u, 1.0, out);
  put_head("euler", "all_null");
  put_status(st);
  put_double(out[0]);
  printf("\n");
  euler_case("exact", y4, f4, 4u, 0.5);
  euler_case("exact_negative_h", y4, f4, 4u, -2.0);
  euler_case("fma", fma_y, fma_f, 1u, 0x1.0000000000001p0);
  euler_case("third", y4, f4, 4u, 1.0 / 3.0);
  euler_case("h_zero", signed_zero, zeros, 4u, 0.0);
  euler_case("h_negative_zero", signed_zero, zeros, 4u, -0.0);
  euler_case("h_zero_one", signed_zero, f4, 4u, 0.0);
  euler_case("h_negative_zero_one", signed_zero, f4, 4u, -0.0);
  euler_case("underflow_tie", zero1, tiny_f, 1u, 0.5);
  euler_case("underflow_up", zero1, tiny_f, 1u, 1.5);
  euler_case("subnormal_sum", tiny_f, tiny_f, 1u, -1.0);
  euler_case("max_plus_one", max1, one1, 1u, 1.0);
  euler_case("product_over", zero1, max1, 1u, 2.0);
  euler_case("sum_over", max1, max1, 1u, 1.0);
  euler_case("sum_over_negative", neg_max1, max1, 1u, -1.0);
  euler_case("cancel", max1, max1, 1u, -1.0);
  euler_case("fail_last", fail_last_y, fail_last_f, 3u, 1.0);
  euler_case("fail_first", fail_first_y, fail_first_f, 3u, 1.0);
  euler_case("h_nan", y4, f4, 4u, VAL_QNAN);
  euler_case("h_snan", y4, f4, 4u, VAL_SNAN);
  euler_case("h_inf", y4, f4, 4u, VAL_INF);
  euler_case("h_inf_zero", y4, zeros, 4u, VAL_INF);
  euler_case("h_negative_inf", y4, f4, 4u, -VAL_INF);
  for (i = 0u; i < 4u; ++i) {
    memcpy(y, y4, sizeof y4);
    memcpy(f, f4, sizeof f4);
    y[i] = VAL_QNAN;
    euler_case("y_nan", y, f, 4u, 1.0);
    y[i] = VAL_INF;
    euler_case("y_inf", y, f, 4u, 1.0);
    y[i] = y4[i];
    f[i] = VAL_SNAN;
    euler_case("f_snan", y, f, 4u, 1.0);
    f[i] = -VAL_INF;
    euler_case("f_inf", y, f, 4u, 0.0);
    y[i] = VAL_INF;
    euler_case("y_f_inf", y, f, 4u, 1.0);
  }

  for (k = 0u; k < RANDOM_ARRAY; ++k) {
    int mixed = (int)(k % 2u);
    size_t d = 1u + (size_t)rng_below(32u);
    double h = random_value(mixed);
    for (i = 0u; i < d; ++i) {
      y[i] = random_value(mixed);
      f[i] = random_value(mixed);
    }
    euler_case("random", y, f, d, h);
  }
}

static void rk4_stage_case(const char *label, const double *y, const double *k,
                           size_t d, double h, int stage) {
  static double out[CAPACITY];
  size_t i;
  diana_status st;

  for (i = 0u; i < CAPACITY; ++i) {
    out[i] = SENTINEL;
  }
  st = diana_rk4_stage(y, k, d, h, stage, out);
  put_head("rk4_stage", label);
  put_double(h);
  printf(" %d", stage);
  put_array(y, y == (const double *)0 ? 0u : d);
  put_array(k, k == (const double *)0 ? 0u : d);
  put_status(st);
  put_array(out, d < CAPACITY ? d : CAPACITY);
  printf("\n");
}

static void rk4_step_case(const char *label, const double *y, const double *k1,
                          const double *k2, const double *k3, const double *k4,
                          size_t d, double h) {
  static double out[CAPACITY];
  size_t i;
  diana_status st;

  for (i = 0u; i < CAPACITY; ++i) {
    out[i] = SENTINEL;
  }
  st = diana_rk4_step(y, k1, k2, k3, k4, d, h, out);
  put_head("rk4_step", label);
  put_double(h);
  put_array(y, y == (const double *)0 ? 0u : d);
  put_array(k1, k1 == (const double *)0 ? 0u : d);
  put_array(k2, k2 == (const double *)0 ? 0u : d);
  put_array(k3, k3 == (const double *)0 ? 0u : d);
  put_array(k4, k4 == (const double *)0 ? 0u : d);
  put_status(st);
  put_array(out, d < CAPACITY ? d : CAPACITY);
  printf("\n");
}

static void test_rk4(void) {
  static const double y4[4] = {1.0, -2.0, 0.5, 0.0};
  static const double a4[4] = {0.5, 0.25, -1.0, 3.0};
  static const double b4[4] = {-1.5, 2.0, 0.75, -0.125};
  static const double c4[4] = {3.0, -0.5, 1.25, 2.0};
  static const double e4[4] = {0.25, 1.0, -2.0, -3.0};
  static const double fma_y[1] = {-1.0};
  static const double fma_k[1] = {0x1.ffffffffffffep-1};
  static const double zeros[4] = {0.0, -0.0, 0.0, -0.0};
  static const double signed_zero[4] = {-0.0, -0.0, 0.0, 0.0};
  static const double zero1[1] = {0.0};
  static const double one1[1] = {1.0};
  static const double max1[1] = {VAL_MAX};
  static const double half_max1[1] = {VAL_HALF_MAX};
  static const double neg_max1[1] = {-VAL_MAX};
  static const double big1[1] = {0x1p1020};
  static const double k1024[1] = {1024.0};
  static const double eps_half[1] = {0x1p-53};
  static const double eps_quarter[1] = {0x1p-54};
  static const double fail_last_y[3] = {1.0, 2.0, VAL_MAX};
  static const double fail_last_k[3] = {1.0, 1.0, VAL_MAX};
  static const double fail_first_y[3] = {VAL_MAX, 2.0, 3.0};
  static const double fail_first_k[3] = {VAL_MAX, 1.0, 1.0};
  static double y[CAPACITY];
  static double k[4][CAPACITY];
  static double out[1] = {SENTINEL};
  diana_status st;
  unsigned n;
  size_t i;
  size_t j;
  int stage;

  rk4_stage_case("null_y", (const double *)0, a4, 4u, 1.0, 2);
  rk4_stage_case("null_k", y4, (const double *)0, 4u, 1.0, 2);
  st = diana_rk4_stage(y4, a4, 4u, 1.0, 2, (double *)0);
  put_head("rk4_stage", "null_out");
  put_status(st);
  printf("\n");
  rk4_stage_case("empty", y4, a4, 0u, 1.0, 2);
  rk4_stage_case("stage_1", y4, a4, 4u, 1.0, 1);
  rk4_stage_case("stage_5", y4, a4, 4u, 1.0, 5);
  rk4_stage_case("stage_negative", y4, a4, 4u, 1.0, -2);
  st = diana_rk4_stage((const double *)0, (const double *)0, 0u, 1.0, 0, out);
  put_head("rk4_stage", "all_null");
  put_status(st);
  put_double(out[0]);
  printf("\n");
  for (stage = 2; stage <= 4; ++stage) {
    rk4_stage_case("exact", y4, a4, 4u, 0.5, stage);
    rk4_stage_case("third", y4, a4, 4u, 1.0 / 3.0, stage);
    rk4_stage_case("h_zero", signed_zero, zeros, 4u, 0.0, stage);
    rk4_stage_case("h_negative_zero", signed_zero, a4, 4u, -0.0, stage);
    rk4_stage_case("coefficient_tie", zero1, k1024, 1u, 3.0 * VAL_TRUE_MIN,
                   stage);
    rk4_stage_case("h_max", zero1, one1, 1u, VAL_MAX, stage);
    rk4_stage_case("product_over", zero1, max1, 1u, 4.0, stage);
    rk4_stage_case("sum_over", max1, max1, 1u, 2.0, stage);
    rk4_stage_case("max_plus_one", max1, one1, 1u, 2.0, stage);
    rk4_stage_case("cancel", max1, max1, 1u, -2.0, stage);
    rk4_stage_case("fail_last", fail_last_y, fail_last_k, 3u, 2.0, stage);
    rk4_stage_case("fail_first", fail_first_y, fail_first_k, 3u, 2.0, stage);
    rk4_stage_case("h_nan", y4, a4, 4u, VAL_QNAN, stage);
    rk4_stage_case("h_snan", y4, a4, 4u, VAL_SNAN, stage);
    rk4_stage_case("h_inf", y4, a4, 4u, VAL_INF, stage);
    rk4_stage_case("h_inf_zero", y4, zeros, 4u, -VAL_INF, stage);
  }
  rk4_stage_case("fma", fma_y, fma_k, 1u, 0x1.0000000000001p0, 4);
  rk4_stage_case("fma_half", fma_y, fma_k, 1u, 0x1.0000000000001p1, 2);
  for (i = 0u; i < 4u; ++i) {
    memcpy(y, y4, sizeof y4);
    memcpy(k[0], a4, sizeof a4);
    y[i] = VAL_QNAN;
    rk4_stage_case("y_nan", y, k[0], 4u, 1.0, 2);
    y[i] = VAL_INF;
    rk4_stage_case("y_inf", y, k[0], 4u, 1.0, 3);
    y[i] = y4[i];
    k[0][i] = VAL_SNAN;
    rk4_stage_case("k_snan", y, k[0], 4u, 1.0, 4);
    k[0][i] = -VAL_INF;
    rk4_stage_case("k_inf", y, k[0], 4u, 0.0, 2);
  }

  rk4_step_case("null_y", (const double *)0, a4, b4, c4, e4, 4u, 1.0);
  rk4_step_case("null_k1", y4, (const double *)0, b4, c4, e4, 4u, 1.0);
  rk4_step_case("null_k2", y4, a4, (const double *)0, c4, e4, 4u, 1.0);
  rk4_step_case("null_k3", y4, a4, b4, (const double *)0, e4, 4u, 1.0);
  rk4_step_case("null_k4", y4, a4, b4, c4, (const double *)0, 4u, 1.0);
  st = diana_rk4_step(y4, a4, b4, c4, e4, 4u, 1.0, (double *)0);
  put_head("rk4_step", "null_out");
  put_status(st);
  printf("\n");
  rk4_step_case("empty", y4, a4, b4, c4, e4, 0u, 1.0);
  rk4_step_case("exact", y4, a4, b4, c4, e4, 4u, 0.75);
  rk4_step_case("third", y4, a4, b4, c4, e4, 4u, 1.0 / 3.0);
  rk4_step_case("weight", zeros, one1, zero1, zero1, zero1, 1u, 6.0);
  rk4_step_case("sum_order", zero1, one1, eps_quarter, eps_quarter, eps_half,
                1u, 6.0);
  rk4_step_case("h_zero", signed_zero, a4, b4, c4, e4, 4u, 0.0);
  rk4_step_case("h_negative_zero", signed_zero, a4, b4, c4, e4, 4u, -0.0);
  rk4_step_case("zero_slope", signed_zero, zeros, zeros, zeros, zeros, 4u, 1.0);
  rk4_step_case("underflow", zero1, one1, zero1, zero1, zero1, 1u,
                VAL_TRUE_MIN);
  rk4_step_case("subnormal", zero1, one1, one1, one1, one1, 1u,
                5.0 * VAL_TRUE_MIN);
  rk4_step_case("k23_over", zero1, zero1, max1, max1, zero1, 1u, 1.0);
  rk4_step_case("double_over", zero1, zero1, max1, zero1, zero1, 1u, 1.0);
  rk4_step_case("slope_over", zero1, max1, half_max1, zero1, zero1, 1u, 1.0);
  rk4_step_case("product_over", zero1, max1, zero1, zero1, zero1, 1u, 2.0);
  rk4_step_case("sum_over", max1, big1, zero1, zero1, zero1, 1u, 6.0);
  rk4_step_case("cancel_k14", zero1, max1, zero1, zero1, neg_max1, 1u, 1.0);
  rk4_step_case("cancel_k23", zero1, zero1, max1, neg_max1, zero1, 1u, 1.0);
  rk4_step_case("max_plus_one", max1, one1, zero1, zero1, zero1, 1u, 6.0);
  rk4_step_case("fail_last", fail_last_y, fail_last_k, fail_last_k, fail_last_k,
                fail_last_k, 3u, 1.0);
  rk4_step_case("fail_first", fail_first_y, fail_first_k, fail_first_k,
                fail_first_k, fail_first_k, 3u, 1.0);
  rk4_step_case("h_nan", y4, a4, b4, c4, e4, 4u, VAL_QNAN);
  rk4_step_case("h_snan", y4, a4, b4, c4, e4, 4u, VAL_SNAN);
  rk4_step_case("h_inf", y4, a4, b4, c4, e4, 4u, VAL_INF);
  rk4_step_case("h_inf_zero", y4, zeros, zeros, zeros, zeros, 4u, -VAL_INF);
  for (i = 0u; i < 4u; ++i) {
    memcpy(y, y4, sizeof y4);
    memcpy(k[0], a4, sizeof a4);
    memcpy(k[1], b4, sizeof b4);
    memcpy(k[2], c4, sizeof c4);
    memcpy(k[3], e4, sizeof e4);
    y[i] = VAL_QNAN;
    rk4_step_case("y_nan", y, k[0], k[1], k[2], k[3], 4u, 1.0);
    y[i] = -VAL_INF;
    rk4_step_case("y_inf", y, k[0], k[1], k[2], k[3], 4u, 1.0);
    y[i] = y4[i];
    for (j = 0u; j < 4u; ++j) {
      double saved = k[j][i];
      k[j][i] = VAL_SNAN;
      rk4_step_case("k_snan", y, k[0], k[1], k[2], k[3], 4u, 1.0);
      k[j][i] = VAL_INF;
      rk4_step_case("k_inf", y, k[0], k[1], k[2], k[3], 4u, 0.0);
      k[j][i] = saved;
    }
  }

  for (n = 0u; n < RANDOM_ARRAY; ++n) {
    int mixed = (int)(n % 2u);
    size_t d = 1u + (size_t)rng_below(32u);
    double h = random_value(mixed);
    stage = 2 + (int)rng_below(3u);
    for (i = 0u; i < d; ++i) {
      y[i] = random_value(mixed);
      for (j = 0u; j < 4u; ++j) {
        k[j][i] = random_value(mixed);
      }
    }
    rk4_stage_case("random", y, k[0], d, h, stage);
    rk4_step_case("random", y, k[0], k[1], k[2], k[3], d, h);
  }
}

typedef double (*newton_fn)(double x, double c, double *dfx);

static double g_linear(double x, double c, double *dfx) {
  *dfx = 1.0;
  return x - c;
}

static double g_square(double x, double c, double *dfx) {
  *dfx = 2.0 * x;
  return x * x - c;
}

static double g_cube(double x, double c, double *dfx) {
  *dfx = 3.0 * x * x;
  return x * x * x - c;
}

static double g_flat(double x, double c, double *dfx) {
  (void)x;
  *dfx = 0.0;
  return c;
}

static double g_cycle(double x, double c, double *dfx) {
  (void)c;
  *dfx = 3.0 * x * x - 2.0;
  return x * x * x - 2.0 * x + 2.0;
}

static void put_newton_state(const diana_newton_state *s) {
  put_double(s->x);
  put_double(s->dx);
  put_double(s->tol);
  printf(" %08x %08x", s->iter, s->max_iter);
}

static uint64_t mix_newton_state(uint64_t h, diana_status st,
                                 const diana_newton_state *s) {
  h = mix(h, (uint64_t)(unsigned)st);
  h = mix(h, to_bits(s->x));
  h = mix(h, to_bits(s->dx));
  h = mix(h, to_bits(s->tol));
  h = mix(h, (uint64_t)s->iter);
  return mix(h, (uint64_t)s->max_iter);
}

static void set_newton_sentinel(diana_newton_state *s) {
  s->x = 7.0;
  s->dx = -0.5;
  s->tol = 0.125;
  s->iter = 3u;
  s->max_iter = 9u;
}

static void newton_init_case(const char *label, double x0, double tol,
                             unsigned max_iter) {
  diana_newton_state s;
  diana_status st;

  set_newton_sentinel(&s);
  st = diana_newton_init(&s, x0, tol, max_iter);
  put_head("newton_init", label);
  put_double(x0);
  put_double(tol);
  printf(" %08x", max_iter);
  put_status(st);
  put_newton_state(&s);
  printf("\n");
}

static void newton_step_case(const char *label, double x0, double fx,
                             double dfx) {
  diana_newton_state s;
  diana_status st;

  set_newton_sentinel(&s);
  st = diana_newton_init(&s, x0, 0.0, 100u);
  put_head("newton_step", label);
  put_status(st);
  st = diana_newton_step(&s, fx, dfx);
  put_double(fx);
  put_double(dfx);
  put_status(st);
  put_newton_state(&s);
  printf("\n");
}

static void newton_run(const char *label, newton_fn f, double c, double x0,
                       double tol, unsigned max_iter, int verbose) {
  diana_newton_state s;
  diana_status st;
  diana_status rst;
  double root = SENTINEL;
  double dx = SENTINEL;
  double dfx;
  uint64_t digest = FNV_OFFSET;
  unsigned steps = 0u;

  set_newton_sentinel(&s);
  st = diana_newton_init(&s, x0, tol, max_iter);
  put_head("newton_run", label);
  put_double(c);
  put_double(x0);
  put_double(tol);
  printf(" %08x", max_iter);
  put_status(st);
  put_newton_state(&s);
  printf("\n");
  while (st == DIANA_CONTINUE && steps < STEP_LIMIT) {
    double fx = f(s.x, c, &dfx);
    st = diana_newton_step(&s, fx, dfx);
    ++steps;
    if (verbose) {
      printf("  step %u", steps);
      put_double(fx);
      put_double(dfx);
      put_status(st);
      put_newton_state(&s);
      printf("\n");
    } else {
      digest = mix_newton_state(digest, st, &s);
    }
  }
  rst = diana_newton_result(&s, &root, &dx);
  printf("  end %u %016llx", steps, (unsigned long long)digest);
  put_status(st);
  put_newton_state(&s);
  put_status(rst);
  put_double(root);
  put_double(dx);
  printf("\n");
}

static void newton_result_case(const char *label, int want_root, int want_dx) {
  diana_newton_state s;
  double root = SENTINEL;
  double dx = SENTINEL;
  diana_status st;

  set_newton_sentinel(&s);
  st = diana_newton_result(&s, want_root ? &root : (double *)0,
                           want_dx ? &dx : (double *)0);
  put_head("newton_result", label);
  put_status(st);
  put_double(root);
  put_double(dx);
  printf("\n");
}

static void test_newton(void) {
  const double inf = VAL_INF;
  const double nan = VAL_QNAN;
  const double tiny = VAL_TRUE_MIN;
  const double eps = 0x1p-52;
  diana_status st;
  unsigned k;

  st = diana_newton_init((diana_newton_state *)0, 0.0, 0.0, 10u);
  put_head("newton_init", "null");
  put_status(st);
  printf("\n");
  newton_init_case("nan_x0", nan, 0.0, 10u);
  newton_init_case("snan_x0", VAL_SNAN, 0.0, 10u);
  newton_init_case("inf_x0", inf, 0.0, 10u);
  newton_init_case("negative_inf_x0", -inf, 0.0, 10u);
  newton_init_case("nan_tol", 0.0, nan, 10u);
  newton_init_case("inf_tol", 0.0, inf, 10u);
  newton_init_case("negative_tol", 0.0, -tiny, 10u);
  newton_init_case("negative_zero_tol", 0.0, -0.0, 10u);
  newton_init_case("zero_iter", 0.0, 0.0, 0u);
  newton_init_case("max_x0", VAL_MAX, 0.0, 10u);
  newton_init_case("subnormal", tiny, tiny, 1u);
  newton_init_case("continue", 2.0, 1e-12, 100u);

  newton_step_case("nan_fx", 1.0, nan, 1.0);
  newton_step_case("snan_fx", 1.0, VAL_SNAN, 1.0);
  newton_step_case("inf_fx", 1.0, inf, 1.0);
  newton_step_case("nan_dfx", 1.0, 1.0, nan);
  newton_step_case("inf_dfx", 1.0, 1.0, -inf);
  newton_step_case("zero_dfx", 1.0, 1.0, 0.0);
  newton_step_case("negative_zero_dfx", 1.0, -1.0, -0.0);
  newton_step_case("zero_fx", 1.0, 0.0, 2.0);
  newton_step_case("negative_zero_fx", 1.0, -0.0, 2.0);
  newton_step_case("zero_fx_zero_dfx", 1.0, 0.0, 0.0);
  newton_step_case("zero_fx_nan_dfx", 1.0, 0.0, nan);
  newton_step_case("tiny_fx", 1.0, 1e-300, 1.0);
  newton_step_case("underflow", 1.0, tiny, 4.0);
  newton_step_case("tie_up", 1.0, -0.5 * eps, 1.0);
  newton_step_case("half_ulp_down", 1.0, 0.5 * eps, 1.0);
  newton_step_case("ulp_up", 1.0, -eps, 1.0);
  newton_step_case("overflow_dx", 1.0, VAL_MAX, 0.5);
  newton_step_case("overflow_dx_subnormal", 1.0, 1.0, tiny);
  newton_step_case("overflow_x", -VAL_MAX, VAL_MAX, 1.0);
  newton_step_case("half_max_x", -VAL_MAX, -VAL_MAX, 2.0);
  newton_step_case("exact", 0.0, -0.5, 1.0);
  newton_step_case("inf_dx_inf_dfx", 1.0, inf, inf);
  st = diana_newton_step((diana_newton_state *)0, 1.0, 1.0);
  put_head("newton_step", "null");
  put_status(st);
  printf("\n");

  newton_run("sqrt2_tol", g_square, 2.0, 2.0, 1e-12, 100u, 1);
  newton_run("sqrt2_from_1", g_square, 2.0, 1.0, 1e-12, 100u, 1);
  newton_run("sqrt2_two_cycle", g_square, 2.0, 2.0, 0.0, 100u, 1);
  newton_run("sqrt2_coarse", g_square, 2.0, 2.0, 1e-6, 100u, 1);
  newton_run("tenth", g_linear, 0.1, 0.0, 0.0, 10u, 1);
  newton_run("third", g_linear, 1.0 / 3.0, 1.0, 0.0, 10u, 1);
  newton_run("cbrt10", g_cube, 10.0, 2.0, 1e-12, 100u, 1);
  newton_run("double_root", g_square, 0.0, 1.0, 0.0, 2100u, 0);
  newton_run("double_root_tol", g_square, 0.0, 1.0, 1e-6, 100u, 1);
  newton_run("cycle", g_cycle, 0.0, 0.0, 1e-12, 8u, 1);
  newton_run("flat", g_flat, 1.0, 2.0, 0.0, 10u, 1);
  newton_run("max_iter_one", g_square, 2.0, 2.0, 1e-12, 1u, 1);
  newton_run("large_root", g_linear, 1e300, 0.0, 0.0, 10u, 1);
  newton_run("square_overflow", g_square, 1.0, VAL_MAX, 0.0, 10u, 1);
  newton_run("no_root", g_square, -1.0, 1.0, 1e-12, 50u, 1);

  st = diana_newton_result((const diana_newton_state *)0, (double *)0,
                           (double *)0);
  put_head("newton_result", "null");
  put_status(st);
  printf("\n");
  newton_result_case("both", 1, 1);
  newton_result_case("root", 1, 0);
  newton_result_case("dx", 0, 1);
  newton_result_case("neither", 0, 0);

  for (k = 0u; k < RANDOM_RUN; ++k) {
    double c = random_bounded((int)(k % 2u));
    double x0 = random_bounded((int)(k % 2u));
    double tol = 0.0;
    unsigned max_iter = 100u;
    newton_fn f = g_linear;

    switch (rng_below(3u)) {
    case 0u:
      f = g_square;
      break;
    case 1u:
      f = g_cube;
      break;
    default:
      break;
    }
    if (rng_below(2u) == 0u) {
      tol = from_bits(to_bits(random_bounded((int)(k % 2u))) & ~SIGN_BIT);
    }
    if (rng_below(8u) == 0u) {
      max_iter = 1u + rng_below(60u);
    }
    newton_run("random", f, c, x0, tol, max_iter, 0);
  }
}

int main(void) {
  test_bisection();
  test_trapezoidal();
  test_simpson();
  test_euler();
  test_rk4();
  test_newton();
  printf("end %u\n", case_count);
  if (fflush(stdout) != 0 || ferror(stdout)) {
    return 1;
  }
  return 0;
}
