#include <float.h>
#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "check.h"
#include "diana/diana.h"

#define SENTINEL 42.0
#define DIM 20u
#define CAP (DIM + 4u)

static uint64_t bits(double x) {
  uint64_t u;

  memcpy(&u, &x, sizeof u);
  return u;
}

static void fill(double *x) {
  size_t p;

  for (p = 0; p < CAP; ++p) {
    x[p] = SENTINEL;
  }
}

/* The solve succeeds, equals want bit for bit and writes only x[0 .. n-1]. */
static void check_ok(const double *lu, const size_t *piv, size_t n,
                     const double *b, const double *want) {
  static double x[CAP];
  size_t p;

  fill(x);
  CHECK_EQ_STATUS(diana_lu_solve(lu, piv, n, b, x), DIANA_OK);
  for (p = 0; p < n; ++p) {
    CHECK(bits(x[p]) == bits(want[p]));
  }
  for (p = n; p < CAP; ++p) {
    CHECK(x[p] == SENTINEL);
  }
}

/* A failure found before the solve starts leaves x untouched. */
static void check_untouched(const double *lu, const size_t *piv, size_t n,
                            const double *b, diana_status want) {
  static double x[CAP];
  size_t p;

  fill(x);
  CHECK_EQ_STATUS(diana_lu_solve(lu, piv, n, b, x), want);
  for (p = 0; p < CAP; ++p) {
    CHECK(x[p] == SENTINEL);
  }
}

/* An overflow during the solve: the contents of x[0 .. n-1] are unspecified,
   but nothing past them is written. */
static void check_overflow(const double *lu, const size_t *piv, size_t n,
                           const double *b) {
  static double x[CAP];
  size_t p;

  fill(x);
  CHECK_EQ_STATUS(diana_lu_solve(lu, piv, n, b, x), DIANA_ERR_ARG);
  for (p = n; p < CAP; ++p) {
    CHECK(x[p] == SENTINEL);
  }
}

/* The right-hand side whose interchanges, in the kernel's order, give c:
   the interchanges undone from the last. */
static void unpermute(const size_t *piv, size_t n, const double *c, double *b) {
  size_t k;
  double t;

  memcpy(b, c, n * sizeof *b);
  for (k = n; k > 0u; --k) {
    t = b[k - 1u];
    b[k - 1u] = b[piv[k - 1u]];
    b[piv[k - 1u]] = t;
  }
}

static void test_argument(void) {
  const double lu[1] = {2.0};
  const size_t piv[1] = {0u};
  const double b[1] = {6.0};
  double x[1] = {SENTINEL};

  CHECK_EQ_STATUS(diana_lu_solve((const double *)0, piv, 1u, b, x),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_lu_solve(lu, (const size_t *)0, 1u, b, x),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_lu_solve(lu, piv, 1u, (const double *)0, x),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_lu_solve(lu, piv, 1u, b, (double *)0), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_lu_solve(lu, piv, 0u, b, x), DIANA_ERR_ARG);
  /* n * n does not fit in size_t: rejected before any access */
  CHECK_EQ_STATUS(diana_lu_solve(lu, piv, (size_t)1 << 32, b, x),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_lu_solve(lu, piv, (size_t)-1, b, x), DIANA_ERR_ARG);
  CHECK(x[0] == SENTINEL);
}

/* Integer L, integer U with power-of-two diagonal and nonzero integer x:
   every operation is exact, so the solve recovers x (an exact zero over a
   negative pivot would come out -0). */
static void test_exact(void) {
  static const double lu1[1] = {2.0};
  static const size_t piv1[1] = {0u};
  static const double b1[1] = {6.0};
  static const double x1[1] = {3.0};
  static double lu[DIM * DIM];
  static size_t piv[DIM];
  static double x[DIM];
  static double y[DIM];
  static double c[DIM];
  static double b[DIM];
  size_t i;
  size_t j;
  size_t k;

  check_ok(lu1, piv1, 1u, b1, x1);
  for (j = 0; j < DIM; ++j) {
    for (i = 0; i < DIM; ++i) {
      if (i > j) {
        lu[i + j * DIM] = (double)((i * 5u + j * 3u) % 5u) - 2.0;
      } else if (i == j) {
        lu[i + j * DIM] =
            (double)(1u << (i % 3u)) * (i % 2u == 1u ? -1.0 : 1.0);
      } else {
        lu[i + j * DIM] = (double)((i * 7u + j) % 11u) - 5.0;
      }
    }
    x[j] = (double)(1u + j % 5u) * (j % 2u == 1u ? -1.0 : 1.0);
    piv[j] = j + (j * 3u) % (DIM - j);
  }
  for (i = 0; i < DIM; ++i) {
    double s = 0.0;
    for (k = i; k < DIM; ++k) {
      s += lu[i + k * DIM] * x[k];
    }
    y[i] = s;
  }
  for (i = 0; i < DIM; ++i) {
    double s = y[i];
    for (k = 0; k < i; ++k) {
      s += lu[i + k * DIM] * y[k];
    }
    c[i] = s;
  }
  unpermute(piv, DIM, c, b);
  check_ok(lu, piv, DIM, b, x);
}

/* Solve A x = b from the factors diana_lu writes. */
static void test_factor(void) {
  /* A = [2 1 1; 4 -6 0; -2 7 2] pivots on row 1, then keeps row 1 on a tie:
     L = [1 0 0; 1/2 1 0; -1/2 1 1], U = [4 -6 0; 0 4 1; 0 0 1] */
  static const double a3[9] = {2.0, 4.0, -2.0, 1.0, -6.0, 7.0, 1.0, 0.0, 2.0};
  static const double b3[3] = {3.0, 16.0, -10.0};
  static const double x3[3] = {1.0, -2.0, 3.0};
  static double lo[DIM * DIM];
  static double up[DIM * DIM];
  static double a[DIM * DIM];
  static double lu[DIM * DIM];
  static size_t piv[DIM];
  static size_t perm[DIM];
  static double x[DIM];
  static double b[DIM];
  size_t i;
  size_t j;
  size_t k;
  size_t r;

  CHECK_EQ_STATUS(diana_lu(a3, 3u, lu, piv), DIANA_OK);
  check_ok(lu, piv, 3u, b3, x3);
  /* A = P^T L U with L in eighths of magnitude below 1, so partial pivoting
     recovers L, U and P exactly (TEST-037), and U with power-of-two
     diagonal, so the solve recovers a nonzero integer x exactly */
  for (j = 0; j < DIM; ++j) {
    for (i = 0; i < DIM; ++i) {
      if (i == j) {
        lo[i + j * DIM] = 1.0;
        up[i + j * DIM] =
            (double)(1u << (i % 3u)) * (i % 2u == 1u ? -1.0 : 1.0);
      } else if (i > j) {
        r = (i * 5u + j * 3u) % 14u;
        lo[i + j * DIM] = (double)((int)r - (r < 7u ? 7 : 6)) / 8.0;
        up[i + j * DIM] = 0.0;
      } else {
        lo[i + j * DIM] = 0.0;
        up[i + j * DIM] = (double)((int)((i * 7u + j) % 11u) - 5);
      }
    }
    perm[j] = (7u * j + 3u) % DIM;
    x[j] = (double)(1u + j % 5u) * (j % 2u == 1u ? -1.0 : 1.0);
  }
  for (j = 0; j < DIM; ++j) {
    for (i = 0; i < DIM; ++i) {
      double s = 0.0;
      for (k = 0; k < DIM; ++k) {
        s += lo[i + k * DIM] * up[k + j * DIM];
      }
      a[perm[i] + j * DIM] = s;
    }
  }
  for (i = 0; i < DIM; ++i) {
    double s = 0.0;
    for (k = 0; k < DIM; ++k) {
      s += a[i + k * DIM] * x[k];
    }
    b[i] = s;
  }
  CHECK_EQ_STATUS(diana_lu(a, DIM, lu, piv), DIANA_OK);
  check_ok(lu, piv, DIM, b, x);
}

/* The interchanges are applied in order k = 0, 1, ..., n-1: (1, 2, 2) turns
   b into (b1, b2, b0), where the reverse order gives (b2, b0, b1). A pivot
   row below k is accepted: any piv[k] < n is an interchange. Only the
   factor's entries are read, so the identity factor returns P b. */
static void test_interchange(void) {
  static const double identity[9] = {1.0, 0.0, 0.0, 0.0, 1.0,
                                     0.0, 0.0, 0.0, 1.0};
  static const size_t piv[3] = {1u, 2u, 2u};
  static const size_t back[3] = {0u, 0u, 1u};
  static const double b[3] = {1.0, 2.0, 3.0};
  static const double want[3] = {2.0, 3.0, 1.0};
  /* (0, 0, 1): b stays, then rows 1, 0 swap, then rows 2, 1 */
  static const double want_back[3] = {2.0, 3.0, 1.0};

  check_ok(identity, piv, 3u, b, want);
  check_ok(identity, back, 3u, b, want_back);
}

/* The quotient is correctly rounded: 5/3 rounds up, 5 * fl(1/3) would round
   down. A zero right-hand side gives -0 over a negative and +0 over a
   positive diagonal. Underflow is not an error: 2^-1074 / 2 is a tie that
   rounds to +0. */
static void test_rounded(void) {
  static const double lu1[1] = {3.0};
  static const size_t piv1[1] = {0u};
  static const double b1[1] = {5.0};
  static const double x1[1] = {0x1.aaaaaaaaaaaabp+0};
  static const double lu2[4] = {-2.0, 0.0, 0.0, 4.0};
  static const size_t piv2[2] = {0u, 1u};
  static const double b2[2] = {0.0, 0.0};
  static const double x2[2] = {-0.0, 0.0};
  static const double two[1] = {2.0};
  static const double tiny[1] = {DBL_TRUE_MIN};
  static const double zero[1] = {0.0};

  check_ok(lu1, piv1, 1u, b1, x1);
  check_ok(lu2, piv2, 2u, b2, x2);
  check_ok(two, piv1, 1u, tiny, zero);
}

/* y1 = (1 + 3*2^-52) - (1 + 2^-52)^2 in the unit forward solve and
   x0 = (1 + 3*2^-52) - (1 + 2^-52)^2 in the back solve, each product rounded
   first, are 2^-52; a fused multiply-add would give 2^-52 - 2^-104. */
static void test_no_contraction(void) {
  static const double lower[4] = {1.0, 1.0 + DBL_EPSILON, 0.0, 1.0};
  static const double upper[4] = {1.0, 0.0, 1.0 + DBL_EPSILON, 1.0};
  static const size_t piv[2] = {0u, 1u};
  static const double fb[2] = {1.0 + DBL_EPSILON, 1.0 + 3.0 * DBL_EPSILON};
  static const double fx[2] = {1.0 + DBL_EPSILON, DBL_EPSILON};
  static const double bb[2] = {1.0 + 3.0 * DBL_EPSILON, 1.0 + DBL_EPSILON};
  static const double bx[2] = {DBL_EPSILON, 1.0 + DBL_EPSILON};

  check_ok(lower, piv, 2u, fb, fx);
  check_ok(upper, piv, 2u, bb, bx);
}

/* The products are subtracted in the order their unknowns were computed:
   2^-53 - (-1) - (-2^-53) is two ties that round to 1; the other order gives
   1 + 2^-52. The forward solve subtracts L[2,0] y0 = -1 first, the back
   solve U[0,2] x2 = -1 first. */
static void test_order(void) {
  static const double lower[9] = {1.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0};
  static const double upper[9] = {1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 1.0};
  static const size_t piv[3] = {0u, 1u, 2u};
  static const double fb[3] = {-1.0, -0x1p-53, 0x1p-53};
  static const double fx[3] = {-1.0, -0x1p-53, 1.0};
  static const double bb[3] = {0x1p-53, -0x1p-53, -1.0};
  static const double bx[3] = {1.0, -0x1p-53, -1.0};

  check_ok(lower, piv, 3u, fb, fx);
  check_ok(upper, piv, 3u, bb, bx);
}

/* The solve is the two substitution kernels bit for bit: forward
   substitution with the unit lower factor on P b (its division by 1 is
   exact), then back substitution with the transposed upper factor. */
static void test_substitution(void) {
  static double lu[DIM * DIM];
  static double lower[DIM * DIM];
  static double upper_t[DIM * DIM];
  static size_t piv[DIM];
  static double b[DIM];
  static double c[DIM];
  static double y[DIM];
  static double want[DIM];
  uint64_t state = UINT64_C(0x9e3779b97f4a7c15);
  size_t n;
  size_t i;
  size_t k;
  double t;

  for (n = 1; n <= DIM; ++n) {
    for (k = 0; k < n; ++k) {
      for (i = 0; i < n; ++i) {
        state = state * UINT64_C(6364136223846793005) + UINT64_C(1);
        lu[i + k * n] = (double)(state >> 11) * 0x1p-53 - 0.5;
        if (i == k) {
          lu[i + k * n] += 4.0;
        }
      }
      state = state * UINT64_C(6364136223846793005) + UINT64_C(1);
      b[k] = (double)(state >> 11) * 0x1p-50 - 4.0;
      piv[k] = (size_t)(state % n);
    }
    for (k = 0; k < n; ++k) {
      for (i = 0; i < n; ++i) {
        if (i > k) {
          lower[i + k * n] = lu[i + k * n];
        } else {
          lower[i + k * n] = i == k ? 1.0 : 0.0;
        }
        upper_t[i + k * n] = i >= k ? lu[k + i * n] : 0.0;
      }
    }
    memcpy(c, b, n * sizeof *c);
    for (k = 0; k < n; ++k) {
      t = c[k];
      c[k] = c[piv[k]];
      c[piv[k]] = t;
    }
    CHECK_EQ_STATUS(diana_forward_substitution(lower, n, c, y), DIANA_OK);
    CHECK_EQ_STATUS(diana_back_substitution(upper_t, n, y, want), DIANA_OK);
    check_ok(lu, piv, n, b, want);
  }
}

static void test_singular(void) {
  static const double zero[1] = {0.0};
  static const double negative_zero[1] = {-0.0};
  static const size_t piv1[1] = {0u};
  static const double b1[1] = {1.0};
  static const double first[9] = {0.0, 1.0, 1.0, 2.0, 1.0, 1.0, 3.0, 4.0, 1.0};
  static const double middle[9] = {1.0, 1.0, 1.0, 2.0, -0.0,
                                   1.0, 3.0, 4.0, 1.0};
  static const double last[9] = {1.0, 1.0, 1.0, 2.0, 1.0, 1.0, 3.0, 4.0, 0.0};
  static const size_t piv3[3] = {2u, 1u, 2u};
  static const double b3[3] = {1.0, 2.0, 3.0};
  /* an argument error comes first */
  static const double nan_b[3] = {1.0, (double)NAN, 3.0};
  static const double nan_lu[9] = {0.0, 1.0, 1.0,         2.0, 1.0,
                                   1.0, 3.0, (double)NAN, 1.0};
  static const size_t bad_piv[3] = {0u, 3u, 2u};

  check_untouched(zero, piv1, 1u, b1, DIANA_ERR_SINGULAR);
  check_untouched(negative_zero, piv1, 1u, b1, DIANA_ERR_SINGULAR);
  check_untouched(first, piv3, 3u, b3, DIANA_ERR_SINGULAR);
  check_untouched(middle, piv3, 3u, b3, DIANA_ERR_SINGULAR);
  check_untouched(last, piv3, 3u, b3, DIANA_ERR_SINGULAR);
  check_untouched(first, piv3, 3u, nan_b, DIANA_ERR_ARG);
  check_untouched(nan_lu, piv3, 3u, b3, DIANA_ERR_ARG);
  check_untouched(first, bad_piv, 3u, b3, DIANA_ERR_ARG);
}

/* A NaN or an infinity anywhere in lu, the strict upper and lower triangles
   included, or in b, and a pivot row outside [0, n), are argument errors
   found before x is written. */
static void test_invalid(void) {
  static const double lubase[9] = {4.0, 0.5, -0.5, -6.0, 4.0,
                                   1.0, 0.0, 1.0,  1.0};
  static const size_t pivbase[3] = {1u, 1u, 2u};
  static const double bbase[3] = {3.0, 16.0, -10.0};
  static const double bad[3] = {(double)NAN, HUGE_VAL, -HUGE_VAL};
  static const size_t bad_row[2] = {3u, (size_t)-1};
  static double lu[9];
  static size_t piv[3];
  static double b[3];
  size_t q;
  size_t v;

  for (v = 0; v < 3u; ++v) {
    for (q = 0; q < 9u; ++q) {
      memcpy(lu, lubase, sizeof lubase);
      lu[q] = bad[v];
      check_untouched(lu, pivbase, 3u, bbase, DIANA_ERR_ARG);
    }
    for (q = 0; q < 3u; ++q) {
      memcpy(b, bbase, sizeof bbase);
      b[q] = bad[v];
      check_untouched(lubase, pivbase, 3u, b, DIANA_ERR_ARG);
    }
  }
  for (v = 0; v < 2u; ++v) {
    for (q = 0; q < 3u; ++q) {
      memcpy(piv, pivbase, sizeof pivbase);
      piv[q] = bad_row[v];
      check_untouched(lubase, piv, 3u, bbase, DIANA_ERR_ARG);
    }
  }
}

/* A difference in the forward solve, or a quotient, a product or a
   difference in the back solve, that overflows makes an entry infinite or
   NaN: an argument error found while x is written. */
static void test_overflow(void) {
  static const size_t piv1[1] = {0u};
  static const size_t piv2[2] = {0u, 1u};
  static const size_t piv3[3] = {0u, 1u, 2u};
  /* forward: -DBL_MAX - 1 * DBL_MAX */
  static const double sum_f[4] = {1.0, 1.0, 0.0, 1.0};
  static const double sum_fb[2] = {DBL_MAX, -DBL_MAX};
  /* forward: finite y0, y1, then 0 - (-inf) - inf is NaN */
  static const double nan_f[9] = {1.0,   0.0, -1e300, 0.0, 1.0,
                                  1e300, 0.0, 0.0,    1.0};
  static const double nan_fb[3] = {1e300, 1e300, 0.0};
  /* back: 1e300 / 1e-300 */
  static const double tiny[1] = {1e-300};
  static const double big[1] = {1e300};
  /* back: the product 1e300 * 1e300 */
  static const double product[4] = {1.0, 0.0, 1e300, 1.0};
  static const double product_b[2] = {0.0, 1e300};
  /* back: DBL_MAX - (-1) * DBL_MAX */
  static const double sum_b[4] = {1.0, 0.0, -1.0, 1.0};
  static const double sum_bb[2] = {DBL_MAX, DBL_MAX};

  check_overflow(sum_f, piv2, 2u, sum_fb);
  check_overflow(nan_f, piv3, 3u, nan_fb);
  check_overflow(tiny, piv1, 1u, big);
  check_overflow(product, piv2, 2u, product_b);
  check_overflow(sum_b, piv2, 2u, sum_bb);
}

int main(void) {
  test_argument();
  test_exact();
  test_factor();
  test_interchange();
  test_rounded();
  test_no_contraction();
  test_order();
  test_substitution();
  test_singular();
  test_invalid();
  test_overflow();
  return check_report("lu_solve");
}
