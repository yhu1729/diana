#include <float.h>
#include <math.h>

#include "check.h"
#include "diana/diana.h"

static double sq_minus_2(double x, void *ctx) {
  (void)ctx;
  return x * x - 2.0;
}

static double cos_minus_x(double x, void *ctx) {
  (void)ctx;
  return cos(x) - x;
}

static double linear(double x, void *ctx) {
  double c = *(const double *)ctx;
  return x - c;
}

static double counted_sq(double x, void *ctx) {
  unsigned *n = (unsigned *)ctx;
  (*n)++;
  return x * x - 2.0;
}

typedef struct {
  double x[3];
  unsigned n;
} eval_record;

static double recorded_sq(double x, void *ctx) {
  eval_record *r = (eval_record *)ctx;
  if (r->n < 3u) {
    r->x[r->n] = x;
  }
  r->n++;
  return x * x - 2.0;
}

static void test_state_machine(void) {
  diana_bisect_state s;
  diana_status st;
  double root = 0.0, width = -1.0;
  double a0 = 0.0, b0 = 2.0;
  unsigned n = 0;

  st = diana_bisect_init(&s, a0, b0, sq_minus_2(a0, 0), sq_minus_2(b0, 0),
                         1e-12, 100u);
  CHECK_EQ_STATUS(st, DIANA_CONTINUE);
  CHECK(s.x == 1.0);
  while (st == DIANA_CONTINUE) {
    double prev_a = s.a, prev_b = s.b;
    st = diana_bisect_step(&s, sq_minus_2(s.x, 0));
    n++;
    CHECK(s.a <= s.b);
    CHECK(prev_a <= s.a && s.b <= prev_b);
    CHECK((s.fa <= 0.0 && s.fb >= 0.0) || (s.fa >= 0.0 && s.fb <= 0.0));
    CHECK(s.b - s.a <= 0.5 * (prev_b - prev_a) + DBL_EPSILON * prev_b);
    CHECK(n < 100u);
  }
  CHECK_EQ_STATUS(st, DIANA_OK);
  CHECK(s.iter == n);
  CHECK_EQ_STATUS(diana_bisect_result(&s, &root, &width), DIANA_OK);
  CHECK(fabs(root - sqrt(2.0)) <= 1e-12);
  CHECK(width >= 0.0 && width <= 1e-12);
  CHECK(n == 41u);
}

static void test_wrapper(void) {
  double root = 0.0;
  unsigned iter = 0;
  double c = 0.75;

  CHECK_EQ_STATUS(
      diana_bisect(sq_minus_2, 0, 0.0, 2.0, 0.0, 200u, &root, &iter), DIANA_OK);
  CHECK(fabs(root - sqrt(2.0)) <= nextafter(sqrt(2.0), 2.0) - sqrt(2.0));
  CHECK(iter > 0u && iter <= 64u);

  CHECK_EQ_STATUS(
      diana_bisect(cos_minus_x, 0, 0.0, 1.0, 1e-10, 100u, &root, &iter),
      DIANA_OK);
  CHECK(fabs(cos(root) - root) <= 1e-9);

  CHECK_EQ_STATUS(diana_bisect(linear, &c, 0.0, 1.0, 1e-15, 100u, &root, &iter),
                  DIANA_OK);
  CHECK(fabs(root - c) <= 1e-15);
}

static void test_exact_hit(void) {
  double root = 1.0;
  double c = 0.5;
  unsigned iter = 99u;
  CHECK_EQ_STATUS(diana_bisect(linear, &c, 0.0, 1.0, 0.0, 100u, &root, &iter),
                  DIANA_OK);
  CHECK(root == 0.5);
  CHECK(iter == 1u);

  c = 0.0;
  CHECK_EQ_STATUS(diana_bisect(linear, &c, 0.0, 1.0, 0.0, 100u, &root, &iter),
                  DIANA_OK);
  CHECK(root == 0.0);
  CHECK(iter == 0u);
  c = 1.0;
  CHECK_EQ_STATUS(diana_bisect(linear, &c, 0.0, 1.0, 0.0, 100u, &root, &iter),
                  DIANA_OK);
  CHECK(root == 1.0);
}

static void test_error(void) {
  diana_bisect_state s;
  double root = 0.0;
  unsigned iter = 0;

  CHECK_EQ_STATUS(
      diana_bisect_init((diana_bisect_state *)0, 0.0, 1.0, -1.0, 1.0, 0.0, 10u),
      DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_bisect_init(&s, 1.0, 0.0, -1.0, 1.0, 0.0, 10u),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_bisect_init(&s, 0.0, 1.0, -1.0, 1.0, -1.0, 10u),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_bisect_init(&s, 0.0, 1.0, -1.0, 1.0, 0.0, 0u),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_bisect_init(&s, (double)NAN, 1.0, -1.0, 1.0, 0.0, 10u),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_bisect_init(&s, 0.0, HUGE_VAL, -1.0, 1.0, 0.0, 10u),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_bisect_init(&s, 0.0, 1.0, (double)NAN, 1.0, 0.0, 10u),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_bisect_init(&s, 0.0, 1.0, -1.0, 1.0, (double)NAN, 10u),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_bisect_init(&s, -DBL_MAX, DBL_MAX, -1.0, 1.0, 0.0, 10u),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_bisect_init(&s, 0.0, 1.0, 1.0, 2.0, 0.0, 10u),
                  DIANA_ERR_BRACKET);
  CHECK_EQ_STATUS(diana_bisect_init(&s, 0.0, 1.0, -1.0, -2.0, 0.0, 10u),
                  DIANA_ERR_BRACKET);

  CHECK_EQ_STATUS(diana_bisect_init(&s, 0.0, 1.0, -1.0, 1.0, 0.0, 10u),
                  DIANA_CONTINUE);
  CHECK_EQ_STATUS(diana_bisect_step((diana_bisect_state *)0, 0.0),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_bisect_step(&s, (double)NAN), DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_bisect_result((const diana_bisect_state *)0, &root, 0),
                  DIANA_ERR_ARG);
  CHECK_EQ_STATUS(diana_bisect_result(&s, (double *)0, (double *)0), DIANA_OK);

  root = -1.0;
  CHECK_EQ_STATUS(
      diana_bisect(sq_minus_2, 0, 0.0, 2.0, 1e-12, 5u, &root, &iter),
      DIANA_ERR_MAXITER);
  CHECK(iter == 5u);
  CHECK(fabs(root - sqrt(2.0)) <= 2.0 / 64.0);
  CHECK_EQ_STATUS(
      diana_bisect((diana_bisect_fn)0, 0, 0.0, 2.0, 1e-12, 5u, &root, &iter),
      DIANA_ERR_ARG);
  CHECK_EQ_STATUS(
      diana_bisect(sq_minus_2, 0, 0.0, 2.0, 1e-12, 5u, (double *)0, &iter),
      DIANA_ERR_ARG);
  root = -1.0;
  CHECK_EQ_STATUS(
      diana_bisect(sq_minus_2, 0, 2.0, 3.0, 1e-12, 5u, &root, &iter),
      DIANA_ERR_BRACKET);
  CHECK(iter == 0u);
  CHECK(root == -1.0);
  iter = 99u;
  CHECK_EQ_STATUS(
      diana_bisect(sq_minus_2, 0, 1.0, 0.0, 1e-12, 5u, &root, &iter),
      DIANA_ERR_ARG);
  CHECK(iter == 0u);
}

static void test_large_magnitude(void) {
  diana_bisect_state s;
  double a = -DBL_MAX / 2.0, b = DBL_MAX / 2.0;
  CHECK_EQ_STATUS(diana_bisect_init(&s, a, b, -1.0, 1.0, 0.0, 2000u),
                  DIANA_CONTINUE);
  CHECK(s.x == 0.0);
  a = DBL_MAX / 4.0;
  b = DBL_MAX / 2.0;
  CHECK_EQ_STATUS(diana_bisect_init(&s, a, b, -1.0, 1.0, 0.0, 2000u),
                  DIANA_CONTINUE);
  CHECK(a < s.x && s.x < b);
  CHECK(isfinite(s.x));
}

static void test_adjacent_termination(void) {
  diana_bisect_state s;
  diana_status st;
  unsigned n = 0;
  double root = 0.0, width = 0.0;
  double target = 1.0 / 3.0;

  st = diana_bisect_init(&s, 0.0, 1.0, linear(0.0, &target),
                         linear(1.0, &target), 0.0, 10000u);
  while (st == DIANA_CONTINUE) {
    st = diana_bisect_step(&s, linear(s.x, &target));
    n++;
  }
  CHECK_EQ_STATUS(st, DIANA_OK);
  CHECK(n <= 64u);
  CHECK_EQ_STATUS(diana_bisect_result(&s, &root, &width), DIANA_OK);
  CHECK(nextafter(s.a, HUGE_VAL) == s.b || s.a == s.b);
  CHECK(fabs(root - target) <= DBL_EPSILON);
}

static void test_worst_case_step_count(void) {
  diana_bisect_state s;
  diana_status st;
  double target = DBL_TRUE_MIN;
  double m = DBL_MAX / 2.0;

  st = diana_bisect_init(&s, -m, m, linear(-m, &target), linear(m, &target),
                         0.0, 2100u);
  while (st == DIANA_CONTINUE) {
    st = diana_bisect_step(&s, linear(s.x, &target));
  }
  CHECK_EQ_STATUS(st, DIANA_OK);
  CHECK(s.iter == 2098u);
  CHECK(s.a <= target && target <= s.b);
}

static int same_state(const diana_bisect_state *p,
                      const diana_bisect_state *q) {
  return p->a == q->a && p->b == q->b && p->fa == q->fa && p->fb == q->fb &&
         p->x == q->x && p->tol == q->tol && p->iter == q->iter &&
         p->max_iter == q->max_iter;
}

static void test_error_keeps_state(void) {
  diana_bisect_state s, before;

  CHECK_EQ_STATUS(diana_bisect_init(&s, 0.0, 1.0, -1.0, 1.0, 0.0, 10u),
                  DIANA_CONTINUE);
  CHECK_EQ_STATUS(diana_bisect_step(&s, -1.0), DIANA_CONTINUE);
  before = s;
  CHECK_EQ_STATUS(diana_bisect_init(&s, 0.0, 1.0, 1.0, 2.0, 0.5, 20u),
                  DIANA_ERR_BRACKET);
  CHECK(same_state(&s, &before));
  CHECK_EQ_STATUS(diana_bisect_init(&s, 1.0, 0.0, -1.0, 1.0, 0.5, 20u),
                  DIANA_ERR_ARG);
  CHECK(same_state(&s, &before));
  CHECK_EQ_STATUS(diana_bisect_step(&s, (double)NAN), DIANA_ERR_ARG);
  CHECK(same_state(&s, &before));
}

static void test_evaluation_count(void) {
  unsigned n = 0, iter = 0;
  double root = 0.0;
  CHECK_EQ_STATUS(
      diana_bisect(counted_sq, &n, 0.0, 2.0, 1e-6, 100u, &root, &iter),
      DIANA_OK);
  CHECK(n == iter + 2u);
  CHECK(iter == 21u);
}

static void test_evaluation_order(void) {
  eval_record r = {{0.0, 0.0, 0.0}, 0u};
  unsigned iter = 0;
  double root = 0.0;
  CHECK_EQ_STATUS(
      diana_bisect(recorded_sq, &r, 0.0, 2.0, 1e-6, 100u, &root, &iter),
      DIANA_OK);
  CHECK(r.n == iter + 2u);
  CHECK(r.x[0] == 0.0 && r.x[1] == 2.0 && r.x[2] == 1.0);
}

int main(void) {
  test_state_machine();
  test_wrapper();
  test_exact_hit();
  test_error();
  test_large_magnitude();
  test_adjacent_termination();
  test_worst_case_step_count();
  test_error_keeps_state();
  test_evaluation_count();
  test_evaluation_order();
  return check_report("bisect");
}
