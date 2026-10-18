#include <float.h>
#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "check.h"
#include "diana/diana.h"

#define SENTINEL 42.0
#define DIM 24u
#define CAP (DIM + 4u)

typedef diana_status (*solve_fn)(const double *, size_t, const double *,
                                 double *);

static uint64_t bits(double x) {
  uint64_t u;

  memcpy(&u, &x, sizeof u);
  return u;
}

static void fill(double *x, size_t count) {
  size_t p;

  for (p = 0; p < count; ++p) {
    x[p] = SENTINEL;
  }
}

/* The solve succeeds, equals want bit for bit and writes only x[0 .. n-1]. */
static void check_ok(solve_fn solve, const double *l, size_t n, const double *b,
                     const double *want) {
  static double x[CAP];
  size_t p;

  fill(x, CAP);
  CHECK_EQ_STATUS(solve(l, n, b, x), DIANA_OK);
  for (p = 0; p < n; ++p) {
    CHECK(bits(x[p]) == bits(want[p]));
  }
  for (p = n; p < CAP; ++p) {
    CHECK(x[p] == SENTINEL);
  }
}

/* A failure found before the solve starts leaves x untouched. */
static void check_untouched(solve_fn solve, const double *l, size_t n,
                            const double *b, diana_status want) {
  static double x[CAP];
  size_t p;

  fill(x, CAP);
  CHECK_EQ_STATUS(solve(l, n, b, x), want);
  for (p = 0; p < CAP; ++p) {
    CHECK(x[p] == SENTINEL);
  }
}

/* An overflow during the solve: the contents of x[0 .. n-1] are unspecified,
   but nothing past them is written. */
static void check_overflow(solve_fn solve, const double *l, size_t n,
                           const double *b) {
  static double x[CAP];
  size_t p;

  fill(x, CAP);
  CHECK_EQ_STATUS(solve(l, n, b, x), DIANA_ERR_OVERFLOW);
  for (p = n; p < CAP; ++p) {
    CHECK(x[p] == SENTINEL);
  }
}

/* b = L x (lower) or b = L^T x (upper) for an integer L and x whose products
   and sums are exact. */
static void apply(const double *l, size_t n, const double *x, int transpose,
                  double *b) {
  size_t i;
  size_t k;

  for (i = 0; i < n; ++i) {
    double s = 0.0;
    for (k = 0; k < n; ++k) {
      if (transpose ? k >= i : k <= i) {
        s += (transpose ? l[k + i * n] : l[i + k * n]) * x[k];
      }
    }
    b[i] = s;
  }
}

static void test_argument(solve_fn solve) {
  const double l[1] = {2.0};
  const double b[1] = {6.0};
  double x[1] = {SENTINEL};

  CHECK_EQ_STATUS(solve((const double *)0, 1u, b, x), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(solve(l, 1u, (const double *)0, x), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(solve(l, 1u, b, (double *)0), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(solve((const double *)0, 0u, (const double *)0, (double *)0),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(solve(l, 0u, b, x), DIANA_ERR_ARG);
  /* n * n does not fit in size_t: rejected before any access */
  CHECK_EQ_STATUS(solve(l, (size_t)1 << 32, b, x), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(solve(l, (size_t)-1, b, x), DIANA_ERR_ARG);
  CHECK(x[0] == SENTINEL);
}

/* Integer L with power-of-two diagonal and integer x: every operation is
   exact, so both solves recover x. */
static void test_exact(void) {
  static const double l1[1] = {2.0};
  static const double b1[1] = {6.0};
  static const double x1[1] = {3.0};
  static const double l3[9] = {2.0, 1.0, -1.0, 0.0, 4.0, 2.0, 0.0, 0.0, 1.0};
  static const double x3[3] = {3.0, -2.0, 5.0};
  static double l[DIM * DIM];
  static double x[DIM];
  static double b[DIM];
  size_t i;
  size_t j;

  check_ok(diana_forward_substitution, l1, 1u, b1, x1);
  check_ok(diana_transpose_substitution, l1, 1u, b1, x1);
  apply(l3, 3u, x3, 0, b);
  check_ok(diana_forward_substitution, l3, 3u, b, x3);
  apply(l3, 3u, x3, 1, b);
  check_ok(diana_transpose_substitution, l3, 3u, b, x3);
  for (j = 0; j < DIM; ++j) {
    for (i = 0; i < DIM; ++i) {
      if (i < j) {
        l[i + j * DIM] = 0.0;
      } else if (i == j) {
        l[i + j * DIM] = (double)(1u << (i % 3u));
      } else {
        l[i + j * DIM] = (double)((i * 7u + j * 3u) % 5u) - 2.0;
      }
    }
    x[j] = (double)(j % 7u) - 3.0;
  }
  apply(l, DIM, x, 0, b);
  check_ok(diana_forward_substitution, l, DIM, b, x);
  apply(l, DIM, x, 1, b);
  check_ok(diana_transpose_substitution, l, DIM, b, x);
}

/* Solve A x = b from the Cholesky factor: L y = b, then L^T x = y. */
static void test_cholesky(void) {
  /* A = L L^T for L = [2 0 0; 1 3 0; -1 2 4], A x = b for x = (1, -2, 3) */
  static const double a[9] = {4.0, 2.0, -2.0, 2.0, 10.0, 5.0, -2.0, 5.0, 21.0};
  static const double b[3] = {-6.0, -3.0, 51.0};
  static const double want[3] = {1.0, -2.0, 3.0};
  double l[9];
  double y[3];
  double x[3];

  CHECK_EQ_STATUS(diana_cholesky(a, 3u, l), DIANA_OK);
  CHECK_EQ_STATUS(diana_forward_substitution(l, 3u, b, y), DIANA_OK);
  CHECK_EQ_STATUS(diana_transpose_substitution(l, 3u, y, x), DIANA_OK);
  CHECK(bits(x[0]) == bits(want[0]));
  CHECK(bits(x[1]) == bits(want[1]));
  CHECK(bits(x[2]) == bits(want[2]));
}

/* Only the lower triangle of l is read: NaN and infinities above the diagonal
   change nothing. */
static void test_upper_ignored(void) {
  static const double l[9] = {2.0, 1.0,      -1.0,      (double)NAN, 4.0,
                              2.0, HUGE_VAL, -HUGE_VAL, 1.0};
  static const double x[3] = {3.0, -2.0, 5.0};
  double b[3];

  apply(l, 3u, x, 0, b);
  check_ok(diana_forward_substitution, l, 3u, b, x);
  apply(l, 3u, x, 1, b);
  check_ok(diana_transpose_substitution, l, 3u, b, x);
}

/* Each quotient is correctly rounded: 5/3 rounds up, 5 * fl(1/3) would round
   down. A zero right-hand side gives +0 over a positive and -0 over a
   negative diagonal. */
static void test_rounded(void) {
  static const double l1[1] = {3.0};
  static const double b1[1] = {5.0};
  static const double x1[1] = {0x1.aaaaaaaaaaaabp+0};
  static const double l2[4] = {-2.0, 0.0, 0.0, 4.0};
  static const double b2[2] = {0.0, 0.0};
  static const double x2[2] = {-0.0, 0.0};

  check_ok(diana_forward_substitution, l1, 1u, b1, x1);
  check_ok(diana_transpose_substitution, l1, 1u, b1, x1);
  check_ok(diana_forward_substitution, l2, 2u, b2, x2);
  check_ok(diana_transpose_substitution, l2, 2u, b2, x2);
}

/* x1 = (1 + 3*2^-52) - (1 + 2^-52)^2 with the product rounded first is
   2^-52; a fused multiply-add would give 2^-52 - 2^-104. */
static void test_no_contraction(void) {
  static const double l[4] = {1.0, 1.0 + DBL_EPSILON, 0.0, 1.0};
  static const double fb[2] = {1.0 + DBL_EPSILON, 1.0 + 3.0 * DBL_EPSILON};
  static const double fx[2] = {1.0 + DBL_EPSILON, DBL_EPSILON};
  static const double bb[2] = {1.0 + 3.0 * DBL_EPSILON, 1.0 + DBL_EPSILON};
  static const double bx[2] = {DBL_EPSILON, 1.0 + DBL_EPSILON};

  check_ok(diana_forward_substitution, l, 2u, fb, fx);
  check_ok(diana_transpose_substitution, l, 2u, bb, bx);
}

/* The products are subtracted in the order their unknowns were computed:
   2^-53 - (-1) - (-2^-53) is two ties that round to 1; the other order gives
   1 + 2^-52. Forward substitution subtracts L[2,0] x0 = -1 first, back
   substitution L[2,0] x2 = -1 first. */
static void test_order(void) {
  static const double fl[9] = {1.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0};
  static const double fb[3] = {-1.0, -0x1p-53, 0x1p-53};
  static const double fx[3] = {-1.0, -0x1p-53, 1.0};
  static const double bl[9] = {1.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0};
  static const double bb[3] = {0x1p-53, -0x1p-53, -1.0};
  static const double bx[3] = {1.0, -0x1p-53, -1.0};

  check_ok(diana_forward_substitution, fl, 3u, fb, fx);
  check_ok(diana_transpose_substitution, bl, 3u, bb, bx);
}

/* Underflow is not an error: 2^-1074 / 2 is a tie that rounds to +0, and a
   subnormal quotient is kept. */
static void test_underflow(void) {
  static const double l[1] = {2.0};
  static const double b[1] = {DBL_TRUE_MIN};
  static const double x[1] = {0.0};
  static const double l2[1] = {0.5};
  static const double x2[1] = {0x1p-1073};

  check_ok(diana_forward_substitution, l, 1u, b, x);
  check_ok(diana_transpose_substitution, l, 1u, b, x);
  check_ok(diana_forward_substitution, l2, 1u, b, x2);
  check_ok(diana_transpose_substitution, l2, 1u, b, x2);
}

/* Back substitution is forward substitution on the system with its indices
   reversed, bit for bit: L'[p, q] = L[n-1-q, n-1-p], b'[p] = b[n-1-p]. */
static void test_reversal(void) {
  static double l[DIM * DIM];
  static double lr[DIM * DIM];
  static double b[DIM];
  static double br[DIM];
  static double x[DIM];
  static double xr[DIM];
  uint64_t state = UINT64_C(0x9e3779b97f4a7c15);
  size_t n;
  size_t i;
  size_t k;

  for (n = 1; n <= DIM; ++n) {
    for (k = 0; k < n; ++k) {
      for (i = 0; i < n; ++i) {
        state = state * UINT64_C(6364136223846793005) + UINT64_C(1);
        l[i + k * n] = (double)(state >> 11) * 0x1p-53 - 0.5;
        if (i == k) {
          l[i + k * n] += 4.0;
        }
      }
      state = state * UINT64_C(6364136223846793005) + UINT64_C(1);
      b[k] = (double)(state >> 11) * 0x1p-50 - 4.0;
    }
    for (k = 0; k < n; ++k) {
      for (i = 0; i < n; ++i) {
        lr[i + k * n] = l[(n - 1u - k) + (n - 1u - i) * n];
      }
      br[k] = b[n - 1u - k];
    }
    CHECK_EQ_STATUS(diana_transpose_substitution(l, n, b, x), DIANA_OK);
    CHECK_EQ_STATUS(diana_forward_substitution(lr, n, br, xr), DIANA_OK);
    for (k = 0; k < n; ++k) {
      CHECK(bits(x[k]) == bits(xr[n - 1u - k]));
    }
  }
}

static void test_singular(solve_fn solve) {
  static const double zero[1] = {0.0};
  static const double negative_zero[1] = {-0.0};
  static const double first[9] = {0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0};
  static const double middle[9] = {1.0, 1.0, 1.0, 0.0, -0.0,
                                   1.0, 0.0, 0.0, 1.0};
  static const double last[9] = {1.0, 1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0};
  static const double b1[1] = {1.0};
  static const double b3[3] = {1.0, 2.0, 3.0};
  /* an argument error comes first */
  static const double nan_b[3] = {1.0, (double)NAN, 3.0};
  static const double nan_l[9] = {0.0,         1.0, 1.0, 0.0, 1.0,
                                  (double)NAN, 0.0, 0.0, 1.0};

  check_untouched(solve, zero, 1u, b1, DIANA_ERR_SINGULAR);
  check_untouched(solve, negative_zero, 1u, b1, DIANA_ERR_SINGULAR);
  check_untouched(solve, first, 3u, b3, DIANA_ERR_SINGULAR);
  check_untouched(solve, middle, 3u, b3, DIANA_ERR_SINGULAR);
  check_untouched(solve, last, 3u, b3, DIANA_ERR_SINGULAR);
  check_untouched(solve, first, 3u, nan_b, DIANA_ERR_ARG);
  check_untouched(solve, nan_l, 3u, b3, DIANA_ERR_ARG);
}

/* A NaN or an infinity in the lower triangle of l or in b is an argument
   error found before x is written. */
static void test_nonfinite(solve_fn solve) {
  static const double lbase[9] = {2.0, 1.0, -1.0, 0.0, 4.0, 2.0, 0.0, 0.0, 1.0};
  static const double bbase[3] = {1.0, 2.0, 3.0};
  static const double bad[3] = {(double)NAN, HUGE_VAL, -HUGE_VAL};
  static double l[9];
  static double b[3];
  size_t i;
  size_t j;
  size_t v;

  for (v = 0; v < 3u; ++v) {
    for (j = 0; j < 3u; ++j) {
      for (i = j; i < 3u; ++i) {
        memcpy(l, lbase, sizeof lbase);
        l[i + j * 3u] = bad[v];
        check_untouched(solve, l, 3u, bbase, DIANA_ERR_ARG);
      }
      memcpy(b, bbase, sizeof bbase);
      b[j] = bad[v];
      check_untouched(solve, lbase, 3u, b, DIANA_ERR_ARG);
    }
  }
}

/* A quotient, a product or a difference that overflows makes a component
   infinite or NaN: an overflow found while x is written. */
static void test_overflow(void) {
  static const double tiny[1] = {1e-300};
  static const double big[1] = {1e300};
  /* the product 1e300 * 1e300 overflows */
  static const double product[4] = {1.0, 1e300, 0.0, 1.0};
  static const double product_b[2] = {1e300, 0.0};
  /* DBL_MAX - (-1) * DBL_MAX overflows */
  static const double sum[4] = {1.0, -1.0, 0.0, 1.0};
  static const double sum_fb[2] = {DBL_MAX, DBL_MAX};
  static const double sum_bb[2] = {DBL_MAX, DBL_MAX};
  /* finite unknowns, then 0 - (-inf) - inf is NaN */
  static const double nan_fl[9] = {1.0,   0.0, -1e300, 0.0, 1.0,
                                   1e300, 0.0, 0.0,    1.0};
  static const double nan_fb[3] = {1e300, 1e300, 0.0};
  static const double nan_bl[9] = {1.0, 1e300, -1e300, 0.0, 1.0,
                                   0.0, 0.0,   0.0,    1.0};
  static const double nan_bb[3] = {0.0, 1e300, 1e300};

  check_overflow(diana_forward_substitution, tiny, 1u, big);
  check_overflow(diana_transpose_substitution, tiny, 1u, big);
  check_overflow(diana_forward_substitution, product, 2u, product_b);
  check_overflow(diana_forward_substitution, sum, 2u, sum_fb);
  check_overflow(diana_transpose_substitution, sum, 2u, sum_bb);
  check_overflow(diana_forward_substitution, nan_fl, 3u, nan_fb);
  check_overflow(diana_transpose_substitution, nan_bl, 3u, nan_bb);
}

int main(void) {
  test_argument(diana_forward_substitution);
  test_argument(diana_transpose_substitution);
  test_exact();
  test_cholesky();
  test_upper_ignored();
  test_rounded();
  test_no_contraction();
  test_order();
  test_underflow();
  test_reversal();
  test_singular(diana_forward_substitution);
  test_singular(diana_transpose_substitution);
  test_nonfinite(diana_forward_substitution);
  test_nonfinite(diana_transpose_substitution);
  test_overflow();
  return check_report("substitution");
}
