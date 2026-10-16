#include <float.h>
#include <math.h>

#include "check.h"
#include "diana/diana.h"

static double sq_minus_2(double x, double *dfx, void *ctx) {
  (void)ctx;
  *dfx = 2.0 * x;
  return x * x - 2.0;
}

static double cube_minus_c(double x, double *dfx, void *ctx) {
  double c = *(const double *)ctx;
  *dfx = 3.0 * x * x;
  return x * x * x - c;
}

static double counted_sq(double x, double *dfx, void *ctx) {
  unsigned *n = (unsigned *)ctx;
  (*n)++;
  *dfx = 2.0 * x;
  return x * x - 2.0;
}

static double flat(double x, double *dfx, void *ctx) {
  (void)x;
  (void)ctx;
  *dfx = 0.0;
  return 1.0;
}

static double no_derivative(double x, double *dfx, void *ctx) {
  (void)dfx;
  (void)ctx;
  return x - 1.0;
}

static double nan_second(double x, double *dfx, void *ctx) {
  unsigned *n = (unsigned *)ctx;
  (*n)++;
  *dfx = 1.0;
  return *n == 2u ? (double)NAN : x - 0.25;
}

static int same_state(const diana_newton_state *p,
                      const diana_newton_state *q) {
  return p->x == q->x && p->dx == q->dx && p->tol == q->tol &&
         p->iter == q->iter && p->max_iter == q->max_iter;
}

/* x^2 - 2 from 2: f'' = 2 and f' >= 2 sqrt(2) on [sqrt(2), 2], so each error
   is at most (2 / (4 sqrt(2))) = 0.354 times the square of the previous one
   while the iterate is above the root; the iteration converges in 6 steps. */
static void test_state_machine(void) {
  diana_newton_state s;
  diana_status st;
  double root = 0.0, dx = -1.0;
  double err, prev = fabs(2.0 - sqrt(2.0));
  unsigned n = 0;

  st = diana_newton_init(&s, 2.0, 1e-12, 100u);
  CHECK_EQ_STATUS(st, DIANA_CONTINUE);
  CHECK(s.x == 2.0 && s.dx == 0.0 && s.tol == 1e-12);
  CHECK(s.iter == 0u && s.max_iter == 100u);
  while (st == DIANA_CONTINUE) {
    double dfx;
    double fx = sq_minus_2(s.x, &dfx, 0);
    st = diana_newton_step(&s, fx, dfx);
    n++;
    CHECK(s.iter == n);
    CHECK(n < 100u);
    err = fabs(s.x - sqrt(2.0));
    if (n <= 5u) {
      CHECK(err <= 0.36 * prev * prev);
    }
    prev = err;
  }
  CHECK_EQ_STATUS(st, DIANA_OK);
  CHECK(n == 6u);
  CHECK_EQ_STATUS(diana_newton_result(&s, &root, &dx), DIANA_OK);
  CHECK(root == s.x && dx == s.dx);
  CHECK(fabs(root - sqrt(2.0)) <= 1e-12);
  CHECK(fabs(dx) <= 1e-12 && dx != 0.0);
}

static void test_exact_hit(void) {
  diana_newton_state s;

  /* x - 1/2 from 0: the first step lands on the root, the second sees f = 0 */
  CHECK_EQ_STATUS(diana_newton_init(&s, 0.0, 0.0, 10u), DIANA_CONTINUE);
  CHECK_EQ_STATUS(diana_newton_step(&s, -0.5, 1.0), DIANA_CONTINUE);
  CHECK(s.x == 0.5 && s.dx == -0.5 && s.iter == 1u);
  CHECK_EQ_STATUS(diana_newton_step(&s, 0.0, 1.0), DIANA_OK);
  CHECK(s.x == 0.5 && s.dx == 0.0 && s.iter == 2u);

  /* an exact zero converges whatever the derivative, even zero */
  CHECK_EQ_STATUS(diana_newton_init(&s, 3.0, 0.0, 10u), DIANA_CONTINUE);
  CHECK_EQ_STATUS(diana_newton_step(&s, 0.0, 0.0), DIANA_OK);
  CHECK(s.x == 3.0 && s.dx == 0.0 && s.iter == 1u);
}

/* tol = 0: the iteration stops when the correction no longer changes x. */
static void test_stagnation(void) {
  diana_newton_state s;

  CHECK_EQ_STATUS(diana_newton_init(&s, 1.0, 0.0, 10u), DIANA_CONTINUE);
  CHECK_EQ_STATUS(diana_newton_step(&s, 1e-300, 1.0), DIANA_OK);
  CHECK(s.x == 1.0 && s.dx == 1e-300 && s.iter == 1u);

  /* the correction underflows to zero */
  CHECK_EQ_STATUS(diana_newton_init(&s, 1.0, 0.0, 10u), DIANA_CONTINUE);
  CHECK_EQ_STATUS(diana_newton_step(&s, DBL_TRUE_MIN, 4.0), DIANA_OK);
  CHECK(s.x == 1.0 && s.dx == 0.0 && s.iter == 1u);

  /* 1 + 2^-53 is a tie that rounds to even, back to 1 */
  CHECK_EQ_STATUS(diana_newton_init(&s, 1.0, 0.0, 10u), DIANA_CONTINUE);
  CHECK_EQ_STATUS(diana_newton_step(&s, -0.5 * DBL_EPSILON, 1.0), DIANA_OK);
  CHECK(s.x == 1.0 && s.dx == -0.5 * DBL_EPSILON);
  /* below 1 the spacing is 2^-53, so the same correction downward moves x */
  CHECK_EQ_STATUS(diana_newton_init(&s, 1.0, 0.0, 10u), DIANA_CONTINUE);
  CHECK_EQ_STATUS(diana_newton_step(&s, 0.5 * DBL_EPSILON, 1.0),
                  DIANA_CONTINUE);
  CHECK(s.x == 1.0 - 0.5 * DBL_EPSILON);
}

/* tol = 0 on x^2 - 2 from 2: after reaching the correctly rounded root the
   computed f is 2^-51, not 0, and the iterate alternates between the two
   doubles around sqrt(2) until the step limit. */
static void test_two_cycle(void) {
  diana_newton_state s;
  diana_status st;
  double hi = sqrt(2.0);
  double lo = nextafter(hi, 0.0);

  st = diana_newton_init(&s, 2.0, 0.0, 100u);
  while (st == DIANA_CONTINUE) {
    double dfx;
    double fx = sq_minus_2(s.x, &dfx, 0);
    st = diana_newton_step(&s, fx, dfx);
    if (s.iter > 6u) {
      CHECK(s.x == hi || s.x == lo);
    }
  }
  CHECK_EQ_STATUS(st, DIANA_ERR_MAXITER);
  CHECK(s.iter == 100u);
  CHECK(s.x == lo && s.dx != 0.0);
}

/* x^2 from 1 has a double root: the error halves at each step, so |dx| <= 1e-6
   first holds at step 20, where x = 2^-20. */
static void test_double_root(void) {
  diana_newton_state s;
  diana_status st;

  st = diana_newton_init(&s, 1.0, 1e-6, 100u);
  while (st == DIANA_CONTINUE) {
    st = diana_newton_step(&s, s.x * s.x, 2.0 * s.x);
  }
  CHECK_EQ_STATUS(st, DIANA_OK);
  CHECK(s.iter == 20u);
  CHECK(s.x == 0x1p-20 && s.dx == 0x1p-20);
}

static void test_max_iter(void) {
  diana_newton_state s;
  diana_status st;
  double root = 0.0, dx = 0.0;

  st = diana_newton_init(&s, 2.0, 1e-12, 3u);
  while (st == DIANA_CONTINUE) {
    double dfx;
    double fx = sq_minus_2(s.x, &dfx, 0);
    st = diana_newton_step(&s, fx, dfx);
  }
  CHECK_EQ_STATUS(st, DIANA_ERR_MAXITER);
  CHECK(s.iter == 3u);
  CHECK(s.x == 1.4142156862745099);
  CHECK_EQ_STATUS(diana_newton_result(&s, &root, &dx), DIANA_OK);
  CHECK(root == 1.4142156862745099 && dx == s.dx);
}

static void test_error(void) {
  diana_newton_state s, before;
  double root = 0.0;

  CHECK_EQ_STATUS(diana_newton_init((diana_newton_state *)0, 0.0, 0.0, 10u),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_newton_init(&s, (double)NAN, 0.0, 10u), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_newton_init(&s, HUGE_VAL, 0.0, 10u), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_newton_init(&s, 0.0, (double)NAN, 10u), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_newton_init(&s, 0.0, -HUGE_VAL, 10u), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_newton_init(&s, 0.0, -DBL_TRUE_MIN, 10u),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_newton_init(&s, 0.0, 0.0, 0u), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_newton_init(&s, 0.0, -0.0, 10u), DIANA_CONTINUE);

  CHECK_EQ_STATUS(diana_newton_init(&s, 1.0, 0.0, 10u), DIANA_CONTINUE);
  before = s;
  CHECK_EQ_STATUS(diana_newton_step((diana_newton_state *)0, 1.0, 1.0),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_newton_step(&s, (double)NAN, 1.0), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_newton_step(&s, 1.0, (double)NAN), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_newton_step(&s, HUGE_VAL, 1.0), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_newton_step(&s, 1.0, -HUGE_VAL), DIANA_ERR_ARG);
  /* zero derivative, either sign of zero */
  CHECK_EQ_STATUS(diana_newton_step(&s, 1.0, 0.0), DIANA_ERR_SINGULAR);
  CHECK_EQ_STATUS(diana_newton_step(&s, -1.0, -0.0), DIANA_ERR_SINGULAR);
  CHECK(same_state(&s, &before));
  /* the correction overflows against a subnormal derivative */
  CHECK_EQ_STATUS(diana_newton_step(&s, DBL_MAX, 0.5), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_newton_step(&s, 1.0, DBL_TRUE_MIN), DIANA_ERR_ARG);
  CHECK(same_state(&s, &before));
  /* the new iterate overflows though the correction is finite */
  CHECK_EQ_STATUS(diana_newton_init(&s, -DBL_MAX, 0.0, 10u), DIANA_CONTINUE);
  before = s;
  CHECK_EQ_STATUS(diana_newton_step(&s, DBL_MAX, 1.0), DIANA_ERR_ARG);
  CHECK(same_state(&s, &before));
  CHECK_EQ_STATUS(diana_newton_step(&s, -DBL_MAX, 2.0), DIANA_CONTINUE);
  CHECK(s.x == -DBL_MAX / 2.0 && s.dx == -DBL_MAX / 2.0 && s.iter == 1u);

  /* a rejected reinitialization keeps the state */
  before = s;
  CHECK_EQ_STATUS(diana_newton_init(&s, 0.0, -1.0, 10u), DIANA_ERR_ARG);
  CHECK(same_state(&s, &before));
  CHECK_EQ_STATUS(diana_newton_init(&s, 0.0, 1.0, 0u), DIANA_ERR_ARG);
  CHECK(same_state(&s, &before));

  CHECK_EQ_STATUS(
      diana_newton_result((const diana_newton_state *)0, &root, (double *)0),
      DIANA_ERR_ARG);
  CHECK(root == 0.0);
  CHECK_EQ_STATUS(diana_newton_result(&s, (double *)0, (double *)0), DIANA_OK);
  CHECK_EQ_STATUS(diana_newton_result(&s, &root, (double *)0), DIANA_OK);
  CHECK(root == s.x);
}

static void test_wrapper(void) {
  double root = 0.0;
  unsigned iter = 0, n = 0;
  double c = 10.0;

  CHECK_EQ_STATUS(diana_newton(sq_minus_2, 0, 2.0, 1e-12, 100u, &root, &iter),
                  DIANA_OK);
  CHECK(fabs(root - sqrt(2.0)) <= 1e-12);
  CHECK(iter == 6u);

  CHECK_EQ_STATUS(
      diana_newton(cube_minus_c, &c, 2.0, 1e-12, 100u, &root, &iter), DIANA_OK);
  CHECK(root == 2.154434690031884);
  CHECK(iter == 5u);

  /* one callback evaluation per step */
  CHECK_EQ_STATUS(
      diana_newton(counted_sq, &n, 2.0, 1e-12, 100u, &root, (unsigned *)0),
      DIANA_OK);
  CHECK(n == 6u);

  /* the step limit still reports the estimate reached */
  root = -1.0;
  CHECK_EQ_STATUS(diana_newton(sq_minus_2, 0, 2.0, 1e-12, 3u, &root, &iter),
                  DIANA_ERR_MAXITER);
  CHECK(iter == 3u);
  CHECK(root == 1.4142156862745099);
}

static void test_wrapper_error(void) {
  double root = -1.0;
  unsigned iter = 99u, n = 0;

  CHECK_EQ_STATUS(
      diana_newton((diana_newton_fn)0, 0, 2.0, 1e-12, 10u, &root, &iter),
      DIANA_ERR_ARG);
  CHECK(iter == 0u && root == -1.0);
  CHECK_EQ_STATUS(diana_newton((diana_newton_fn)0, 0, 2.0, 1e-12, 10u, &root,
                               (unsigned *)0),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(
      diana_newton(sq_minus_2, 0, 2.0, 1e-12, 10u, (double *)0, &iter),
      DIANA_ERR_ARG);
  CHECK(iter == 0u);

  /* init rejects the arguments: no callback evaluation */
  iter = 99u;
  CHECK_EQ_STATUS(
      diana_newton(counted_sq, &n, (double)NAN, 1e-12, 10u, &root, &iter),
      DIANA_ERR_ARG);
  CHECK(iter == 0u && n == 0u && root == -1.0);
  CHECK_EQ_STATUS(diana_newton(counted_sq, &n, 2.0, -1.0, 10u, &root, &iter),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_newton(counted_sq, &n, 2.0, 0.0, 0u, &root, &iter),
                  DIANA_ERR_ARG);
  CHECK(n == 0u);

  /* a zero derivative, and a callback that never writes it */
  iter = 99u;
  CHECK_EQ_STATUS(diana_newton(flat, 0, 2.0, 1e-12, 10u, &root, &iter),
                  DIANA_ERR_SINGULAR);
  CHECK(iter == 0u && root == -1.0);
  CHECK_EQ_STATUS(diana_newton(no_derivative, 0, 2.0, 1e-12, 10u, &root, &iter),
                  DIANA_ERR_SINGULAR);
  CHECK(iter == 0u && root == -1.0);

  /* a non-finite value on the second call: one step completed, root untouched
   */
  n = 0;
  CHECK_EQ_STATUS(diana_newton(nan_second, &n, 0.0, 0.0, 10u, &root, &iter),
                  DIANA_ERR_ARG);
  CHECK(iter == 1u && n == 2u && root == -1.0);
}

int main(void) {
  test_state_machine();
  test_exact_hit();
  test_stagnation();
  test_two_cycle();
  test_double_root();
  test_max_iter();
  test_error();
  test_wrapper();
  test_wrapper_error();
  return check_report("newton");
}
