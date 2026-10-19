#include <stddef.h>

#include "benchmark.h"
#include "diana/newton.h"

static double f(double x, double *dfx, void *ctx) {
  (void)ctx;
  *dfx = 2.0 * x;
  return x * x - 2.0;
}

/* One solve of x^2 = 2 from 2 to tol 1e-12 (six steps); a unit is a step. */
static size_t step(void *data) {
  diana_newton_state s;
  double root;
  double dx;
  double dfx;
  double fx;
  diana_status st;

  (void)data;
  st = diana_newton_init(&s, 2.0, 1e-12, 100u);
  while (st == DIANA_CONTINUE) {
    fx = f(s.x, &dfx, NULL);
    st = diana_newton_step(&s, fx, dfx);
  }
  if (st != DIANA_OK || diana_newton_result(&s, &root, &dx) != DIANA_OK) {
    return 0;
  }
  return s.iter;
}

static size_t wrapper(void *data) {
  double root;
  unsigned iter;

  (void)data;
  if (diana_newton(f, NULL, 2.0, 1e-12, 100u, &root, &iter) != DIANA_OK) {
    return 0;
  }
  return iter;
}

static const struct diana_benchmark_case item[] = {
    {"newton_step", "step", NULL, 0, NULL, step, NULL},
    {"newton", "step", NULL, 0, NULL, wrapper, NULL}};

const struct diana_benchmark_suite diana_benchmark_newton = {
    item, sizeof item / sizeof item[0]};
