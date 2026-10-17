#include <float.h>
#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "check.h"
#include "diana/diana.h"

#define SENTINEL 42.0
#define DIM 20u
#define CAP (DIM * DIM + 4u)

static uint64_t bits(double x) {
  uint64_t u;

  memcpy(&u, &x, sizeof u);
  return u;
}

static void fill(double *l, size_t count) {
  size_t p;

  for (p = 0; p < count; ++p) {
    l[p] = SENTINEL;
  }
}

/* a = L L^T in column-major order for an integer lower-triangular L whose
   products and sums are exact. */
static void gram(const double *lo, size_t n, double *a) {
  size_t i;
  size_t j;
  size_t k;

  for (j = 0; j < n; ++j) {
    for (i = 0; i < n; ++i) {
      double s = 0.0;
      for (k = 0; k <= (i < j ? i : j); ++k) {
        s += lo[i + k * n] * lo[j + k * n];
      }
      a[i + j * n] = s;
    }
  }
}

/* The factorization succeeds, equals want bit for bit (want is lower
   triangular, the strict upper triangle zero) and writes only l[0 .. n*n-1].
 */
static void check_ok(const double *a, size_t n, const double *want) {
  static double l[CAP];
  size_t p;

  fill(l, CAP);
  CHECK_EQ_STATUS(diana_cholesky(a, n, l), DIANA_OK);
  for (p = 0; p < n * n; ++p) {
    CHECK(bits(l[p]) == bits(want[p]));
  }
  for (p = n * n; p < CAP; ++p) {
    CHECK(l[p] == SENTINEL);
  }
}

static void check_arg(const double *a, size_t n) {
  static double l[CAP];
  size_t p;

  fill(l, CAP);
  CHECK_EQ_STATUS(diana_cholesky(a, n, l), DIANA_ERR_ARG);
  for (p = 0; p < CAP; ++p) {
    CHECK(l[p] == SENTINEL);
  }
}

/* The contents of l[0 .. n*n-1] are unspecified on DIANA_ERR_SINGULAR, but
   nothing past them is written. */
static void check_singular(const double *a, size_t n) {
  static double l[CAP];
  size_t p;

  fill(l, CAP);
  CHECK_EQ_STATUS(diana_cholesky(a, n, l), DIANA_ERR_SINGULAR);
  for (p = n * n; p < CAP; ++p) {
    CHECK(l[p] == SENTINEL);
  }
}

static void test_argument(void) {
  const double a[1] = {4.0};
  double l[1] = {SENTINEL};

  CHECK_EQ_STATUS(diana_cholesky((const double *)0, 1u, l), DIANA_ERR_ARG);
  CHECK(l[0] == SENTINEL);
  CHECK_EQ_STATUS(diana_cholesky(a, 1u, (double *)0), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_cholesky((const double *)0, 0u, (double *)0),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_cholesky(a, 0u, l), DIANA_ERR_ARG);
  CHECK(l[0] == SENTINEL);
  /* n * n does not fit in size_t: rejected before any access */
  CHECK_EQ_STATUS(diana_cholesky(a, (size_t)1 << 32, l), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_cholesky(a, (size_t)-1, l), DIANA_ERR_ARG);
  CHECK(l[0] == SENTINEL);
}

/* L with small integer entries and square pivots: every operation is exact,
   so the kernel recovers L. */
static void test_exact(void) {
  static const double one[1] = {16.0};
  static const double one_l[1] = {4.0};
  static const double lo3[9] = {2.0, 1.0, -1.0, 0.0, 3.0, 2.0, 0.0, 0.0, 4.0};
  static const double lo4[16] = {1.0, -2.0, 3.0, 1.0, 0.0, 2.0, 1.0, -1.0,
                                 0.0, 0.0,  5.0, 2.0, 0.0, 0.0, 0.0, 3.0};
  static double lo[DIM * DIM];
  static double a[DIM * DIM];
  size_t i;
  size_t j;

  check_ok(one, 1u, one_l);
  gram(lo3, 3u, a);
  check_ok(a, 3u, lo3);
  gram(lo4, 4u, a);
  check_ok(a, 4u, lo4);
  for (j = 0; j < DIM; ++j) {
    for (i = 0; i < DIM; ++i) {
      lo[i + j * DIM] =
          i < j ? 0.0
                : (i == j ? (double)(1u + i % 3u) : (double)(i + j) - 19.0);
    }
  }
  gram(lo, DIM, a);
  check_ok(a, DIM, lo);
}

/* Only the lower triangle of a is read: NaN and infinities above the diagonal
   change nothing. */
static void test_upper_ignored(void) {
  static const double a[9] = {4.0, 2.0,      -2.0,      (double)NAN, 10.0,
                              5.0, HUGE_VAL, -HUGE_VAL, 21.0};
  static const double want[9] = {2.0, 1.0, -1.0, 0.0, 3.0, 2.0, 0.0, 0.0, 4.0};

  check_ok(a, 3u, want);
}

static void test_diagonal(void) {
  static const double a[9] = {4.0, 0.0, 0.0, 0.0, 9.0, -0.0, 0.0, 0.0, 0.25};
  static const double want[9] = {2.0, 0.0, 0.0, 0.0, 3.0, -0.0, 0.0, 0.0, 0.5};

  check_ok(a, 3u, want);
}

/* The square root and the division are correctly rounded. */
static void test_rounded(void) {
  static const double a1[1] = {2.0};
  static const double a2[4] = {9.0, 5.0, 0.0, 100.0};
  double want1[1];
  double want2[4];

  want1[0] = sqrt(2.0);
  check_ok(a1, 1u, want1);
  /* 5/3 rounds up; 5 * fl(1/3) would round down */
  want2[0] = 3.0;
  want2[1] = 0x1.aaaaaaaaaaaabp+0;
  want2[2] = 0.0;
  want2[3] = sqrt(100.0 - want2[1] * want2[1]);
  check_ok(a2, 2u, want2);
}

/* The pivot 1 + 3*2^-52 - (1 + 2^-52)^2 with the product rounded first is
   2^-52, a square; a fused multiply-add would give 2^-52 - 2^-104, whose
   root rounds to 2^-26 * (1 - 2^-53). */
static void test_no_contraction(void) {
  static const double a[4] = {1.0, 1.0 + DBL_EPSILON, 0.0,
                              1.0 + 3.0 * DBL_EPSILON};
  static const double want[4] = {1.0, 1.0 + DBL_EPSILON, 0.0, 0x1p-26};

  check_ok(a, 2u, want);
}

/* The pivot of column 2 is 1 - 2^-54 - 2^-54 subtracted in order: both
   steps are ties that round back to 1. Summing the products first would give
   1 - 2^-53, whose root rounds to 1 - 2^-53. */
static void test_order(void) {
  static const double a[9] = {1.0,     0.0, 0x1p-27, 0.0, 1.0,
                              0x1p-27, 0.0, 0.0,     1.0};
  static const double want[9] = {1.0,     0.0, 0x1p-27, 0.0, 1.0,
                                 0x1p-27, 0.0, 0.0,     1.0};

  check_ok(a, 3u, want);
}

/* A subnormal pivot is positive: its root is normal. */
static void test_subnormal(void) {
  static const double a[4] = {DBL_TRUE_MIN, 0.0, 0.0, 0x1p-1072};
  static const double want[4] = {0x1p-537, 0.0, 0.0, 0x1p-536};

  check_ok(a, 2u, want);
}

static void test_singular(void) {
  static const double zero[4] = {0.0, 0.0, 0.0, 0.0};
  static const double negative_zero[1] = {-0.0};
  static const double negative[1] = {-1.0};
  static const double indefinite[4] = {1.0, 2.0, 2.0, 1.0};
  static const double semidefinite[4] = {1.0, 1.0, 1.0, 1.0};
  static const double last[9] = {4.0, 2.0, 0.0, 0.0, 2.0, 1.0, 0.0, 0.0, 0.5};
  /* 1e300 / 2^-537 overflows: the next pivot is 1 - inf = -inf */
  static const double overflow[4] = {DBL_TRUE_MIN, 1e300, 0.0, 1.0};
  /* l20 = inf and l10 = 0, so l21 = (1 - inf * 0) / 1 is NaN and so is the
     pivot of column 2 */
  static const double nan_pivot[9] = {DBL_TRUE_MIN, 0.0, 1e300, 0.0, 1.0,
                                      1.0,          0.0, 0.0,   1.0};

  check_singular(zero, 2u);
  check_singular(negative_zero, 1u);
  check_singular(negative, 1u);
  check_singular(indefinite, 2u);
  check_singular(semidefinite, 2u);
  check_singular(last, 3u);
  check_singular(overflow, 2u);
  check_singular(nan_pivot, 3u);
}

/* A NaN or an infinity anywhere in the lower triangle is an argument error
   found before l is written. */
static void test_nonfinite(void) {
  static const double base[9] = {4.0, 2.0, -2.0, 0.0, 10.0,
                                 5.0, 0.0, 0.0,  21.0};
  static const double bad[3] = {(double)NAN, HUGE_VAL, -HUGE_VAL};
  static double a[9];
  size_t i;
  size_t j;
  size_t v;

  for (j = 0; j < 3u; ++j) {
    for (i = j; i < 3u; ++i) {
      for (v = 0; v < 3u; ++v) {
        memcpy(a, base, sizeof base);
        a[i + j * 3u] = bad[v];
        check_arg(a, 3u);
      }
    }
  }
}

int main(void) {
  test_argument();
  test_exact();
  test_upper_ignored();
  test_diagonal();
  test_rounded();
  test_no_contraction();
  test_order();
  test_subnormal();
  test_singular();
  test_nonfinite();
  return check_report("cholesky");
}
