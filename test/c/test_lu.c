#include <float.h>
#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "check.h"
#include "diana/diana.h"

#define SENTINEL 42.0
#define PIV_SENTINEL ((size_t)77)
#define DIM 20u
#define CAP (DIM * DIM + 4u)
#define PIV_CAP (DIM + 4u)

static uint64_t bits(double x) {
  uint64_t u;

  memcpy(&u, &x, sizeof u);
  return u;
}

static void fill(double *lu, size_t *piv) {
  size_t q;

  for (q = 0; q < CAP; ++q) {
    lu[q] = SENTINEL;
  }
  for (q = 0; q < PIV_CAP; ++q) {
    piv[q] = PIV_SENTINEL;
  }
}

/* The factorization succeeds, equals want and want_piv bit for bit, and
   writes only lu[0 .. n*n-1] and piv[0 .. n-1]. */
static void check_ok(const double *a, size_t n, const double *want,
                     const size_t *want_piv) {
  static double lu[CAP];
  static size_t piv[PIV_CAP];
  size_t q;

  fill(lu, piv);
  CHECK_EQ_STATUS(diana_lu(a, n, lu, piv), DIANA_OK);
  for (q = 0; q < n * n; ++q) {
    CHECK(bits(lu[q]) == bits(want[q]));
  }
  for (q = n * n; q < CAP; ++q) {
    CHECK(lu[q] == SENTINEL);
  }
  for (q = 0; q < n; ++q) {
    CHECK(piv[q] == want_piv[q]);
  }
  for (q = n; q < PIV_CAP; ++q) {
    CHECK(piv[q] == PIV_SENTINEL);
  }
}

/* A non-finite entry of a: nothing is written. */
static void check_untouched(const double *a, size_t n) {
  static double lu[CAP];
  static size_t piv[PIV_CAP];
  size_t q;

  fill(lu, piv);
  CHECK_EQ_STATUS(diana_lu(a, n, lu, piv), DIANA_ERR_ARG);
  for (q = 0; q < CAP; ++q) {
    CHECK(lu[q] == SENTINEL);
  }
  for (q = 0; q < PIV_CAP; ++q) {
    CHECK(piv[q] == PIV_SENTINEL);
  }
}

/* A zero pivot or an overflow: the contents of lu[0 .. n*n-1] and
   piv[0 .. n-1] are unspecified, but nothing past them is written. */
static void check_fail(const double *a, size_t n, diana_status want) {
  static double lu[CAP];
  static size_t piv[PIV_CAP];
  size_t q;

  fill(lu, piv);
  CHECK_EQ_STATUS(diana_lu(a, n, lu, piv), want);
  for (q = n * n; q < CAP; ++q) {
    CHECK(lu[q] == SENTINEL);
  }
  for (q = n; q < PIV_CAP; ++q) {
    CHECK(piv[q] == PIV_SENTINEL);
  }
}

static void test_argument(void) {
  const double a[1] = {4.0};
  double lu[1] = {SENTINEL};
  size_t piv[1] = {PIV_SENTINEL};

  CHECK_EQ_STATUS(diana_lu((const double *)0, 1u, lu, piv), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_lu(a, 1u, (double *)0, piv), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_lu(a, 1u, lu, (size_t *)0), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_lu(a, 0u, lu, piv), DIANA_ERR_ARG);
  /* n * n does not fit in size_t: rejected before any access */
  CHECK_EQ_STATUS(diana_lu(a, (size_t)1 << 32, lu, piv), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_lu(a, (size_t)-1, lu, piv), DIANA_ERR_ARG);
  CHECK(lu[0] == SENTINEL);
  CHECK(piv[0] == PIV_SENTINEL);
}

static void test_one(void) {
  static const double a[1] = {-5.0};
  static const size_t piv[1] = {0u};

  check_ok(a, 1u, a, piv);
}

/* The pivot is the first entry of largest magnitude, and rows are swapped
   across every column, including the multipliers already stored. */
static void test_pivot(void) {
  /* A = [[1, 2], [-3, 4]]: row 1 is the pivot, l = 1 / -3 rounded */
  static const double a2[4] = {1.0, -3.0, 2.0, 4.0};
  static const double lu2[4] = {-3.0, -0x1.5555555555555p-2, 4.0,
                                0x1.aaaaaaaaaaaaap+1};
  static const size_t piv2[2] = {1u, 1u};
  /* a tie, |1| = |-1|, keeps row 0 */
  static const double tie[4] = {1.0, -1.0, 1.0, 1.0};
  static const double tie_lu[4] = {1.0, -1.0, 1.0, 2.0};
  static const size_t tie_piv[2] = {0u, 1u};
  /* column 0 is [2, -3, 3]: row 1, the first of magnitude 3; then column 1
     below the pivot is [8/3, -8]: rows 1 and 2 swap, multipliers included */
  static const double a3[9] = {2.0, -3.0, 3.0, 2.0, 1.0, -9.0, 1.0, 0.0, 6.0};
  static const double lu3[9] = {-3.0, -1.0, -0x1.5555555555555p-1,
                                1.0,  -8.0, -0x1.5555555555555p-2,
                                0.0,  6.0,  3.0};
  static const size_t piv3[3] = {1u, 2u, 2u};

  check_ok(a2, 2u, lu2, piv2);
  check_ok(tie, 2u, tie_lu, tie_piv);
  check_ok(a3, 3u, lu3, piv3);
}

/* A = P^T L U with 0 < |L[i][k]| < 1 below the diagonal, so partial pivoting
   recovers P; L has entries in eighths and U small integers, so every
   operation is exact and the kernel returns L and U bit for bit (a zero
   multiplier would come out as -0 below a negative pivot). */
static void test_exact(void) {
  static double lo[DIM * DIM];
  static double up[DIM * DIM];
  static double a[DIM * DIM];
  static double want[DIM * DIM];
  static size_t perm[DIM];
  static size_t cur[DIM];
  static size_t want_piv[DIM];
  size_t i;
  size_t j;
  size_t k;
  size_t p;
  size_t r;

  for (j = 0; j < DIM; ++j) {
    for (i = 0; i < DIM; ++i) {
      if (i == j) {
        lo[i + j * DIM] = 1.0;
        up[i + j * DIM] = (double)(1u + i % 3u) * (i % 2u == 1u ? -1.0 : 1.0);
      } else if (i > j) {
        r = (i * 5u + j * 3u) % 14u;
        lo[i + j * DIM] = (double)((int)r - (r < 7u ? 7 : 6)) / 8.0;
        up[i + j * DIM] = 0.0;
      } else {
        lo[i + j * DIM] = 0.0;
        up[i + j * DIM] = (double)((int)((i * 7u + j) % 11u) - 5);
      }
    }
  }
  for (i = 0; i < DIM; ++i) {
    perm[i] = (7u * i + 3u) % DIM;
    cur[i] = i;
  }
  for (j = 0; j < DIM; ++j) {
    for (i = 0; i < DIM; ++i) {
      double s = 0.0;
      for (k = 0; k < DIM; ++k) {
        s += lo[i + k * DIM] * up[k + j * DIM];
      }
      a[perm[i] + j * DIM] = s;
      want[i + j * DIM] = i > j ? lo[i + j * DIM] : up[i + j * DIM];
    }
  }
  for (k = 0; k < DIM; ++k) {
    p = k;
    while (cur[p] != perm[k]) {
      ++p;
    }
    want_piv[k] = p;
    r = cur[k];
    cur[k] = cur[p];
    cur[p] = r;
  }
  check_ok(a, DIM, want, want_piv);
}

/* The multiplier is a correctly rounded division: 3/5 rounds down, where
   3 * fl(1/5) would round up. */
static void test_rounded(void) {
  static const double a[4] = {5.0, 3.0, 1.0, 1.0};
  static const double want[4] = {5.0, 0x1.3333333333333p-1, 1.0,
                                 0x1.999999999999ap-2};
  static const size_t piv[2] = {0u, 1u};

  check_ok(a, 2u, want, piv);
}

/* 2 - (1 - 2^-53) * (1 + 2^-52) with the product rounded first is 1; a fused
   multiply-add would give 1 - 2^-53. */
static void test_no_contraction(void) {
  static const double a[4] = {1.0, 1.0 - DBL_EPSILON / 2.0, 1.0 + DBL_EPSILON,
                              2.0};
  static const double want[4] = {1.0, 1.0 - DBL_EPSILON / 2.0,
                                 1.0 + DBL_EPSILON, 1.0};
  static const size_t piv[2] = {0u, 1u};

  check_ok(a, 2u, want, piv);
}

/* U[2][2] is 1 - 2^-54 - 2^-54 subtracted in order: both steps are ties that
   round back to 1. Summing the products first would give 1 - 2^-53. */
static void test_order(void) {
  static const double a[9] = {1.0,     0.0,     0x1p-27, 0.0, 1.0,
                              0x1p-27, 0x1p-27, 0x1p-27, 1.0};
  static const double want[9] = {1.0,     0.0,     0x1p-27, 0.0, 1.0,
                                 0x1p-27, 0x1p-27, 0x1p-27, 1.0};
  static const size_t piv[3] = {0u, 1u, 2u};

  check_ok(a, 3u, want, piv);
}

/* Signed zeros and subnormals are kept: -0 / 2 is -0, and a product that
   underflows is not an error: 2^-538 * 3 * 2^-537 rounds to 2^-1073. */
static void test_small(void) {
  static const double a[4] = {2.0, -0.0, DBL_TRUE_MIN, 0x1p-1060};
  static const double b[4] = {1.0, 0x1p-538, 0x1.8p-536, 0x1p-1060};
  static const double want_b[4] = {1.0, 0x1p-538, 0x1.8p-536,
                                   0x1p-1060 - 0x1p-1073};
  static const size_t piv[2] = {0u, 1u};

  check_ok(a, 2u, a, piv);
  check_ok(b, 2u, want_b, piv);
}

static void test_singular(void) {
  static const double zero[1] = {0.0};
  static const double negative_zero[4] = {-0.0, 0.0, 0.0, 1.0};
  static const double column[4] = {0.0, 0.0, 1.0, 1.0};
  static const double rank_one[4] = {1.0, 2.0, 2.0, 4.0};
  static const double last[9] = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0};

  check_fail(zero, 1u, DIANA_ERR_SINGULAR);
  check_fail(negative_zero, 2u, DIANA_ERR_SINGULAR);
  check_fail(column, 2u, DIANA_ERR_SINGULAR);
  check_fail(rank_one, 2u, DIANA_ERR_SINGULAR);
  check_fail(last, 3u, DIANA_ERR_SINGULAR);
}

/* An update that overflows is an argument error found after lu is written:
   DBL_MAX - 1 * (-DBL_MAX) is +inf. */
static void test_overflow(void) {
  static const double a2[4] = {1.0, 1.0, -DBL_MAX, DBL_MAX};
  /* step 0: three updates are finite and written, the fourth overflows */
  static const double a3[9] = {1.0,     0.5,      -1.0, 1.0,     1.0,
                               DBL_MAX, -DBL_MAX, 0.0,  -DBL_MAX};

  check_fail(a2, 2u, DIANA_ERR_ARG);
  check_fail(a3, 3u, DIANA_ERR_ARG);
}

/* A NaN or an infinity anywhere in a is an argument error found before lu or
   piv is written. */
static void test_nonfinite(void) {
  static const double base[9] = {4.0, 2.0, -2.0, 1.0, 10.0,
                                 5.0, 3.0, 7.0,  21.0};
  static const double bad[3] = {(double)NAN, HUGE_VAL, -HUGE_VAL};
  static double a[9];
  size_t q;
  size_t v;

  for (q = 0; q < 9u; ++q) {
    for (v = 0; v < 3u; ++v) {
      memcpy(a, base, sizeof base);
      a[q] = bad[v];
      check_untouched(a, 3u);
    }
  }
}

int main(void) {
  test_argument();
  test_one();
  test_pivot();
  test_exact();
  test_rounded();
  test_no_contraction();
  test_order();
  test_small();
  test_singular();
  test_overflow();
  test_nonfinite();
  return check_report("lu");
}
