#include <stddef.h>

#include "benchmark.h"
#include "diana/bisection.h"

static double f(double x, void *ctx) {
  (void)ctx;
  return x * x - 2.0;
}

/* One solve of x^2 = 2 on [0, 2] down to adjacent doubles; a unit is a step. */
static size_t step(void *data) {
  diana_bisection_state s;
  double root;
  double width;
  diana_status st;

  (void)data;
  st =
      diana_bisection_init(&s, 0.0, 2.0, f(0.0, NULL), f(2.0, NULL), 0.0, 200u);
  while (st == DIANA_CONTINUE) {
    st = diana_bisection_step(&s, f(s.x, NULL));
  }
  if (st != DIANA_OK || diana_bisection_result(&s, &root, &width) != DIANA_OK) {
    return 0;
  }
  return s.iter;
}

static size_t wrapper(void *data) {
  double root;
  unsigned iter;

  (void)data;
  if (diana_bisection(f, NULL, 0.0, 2.0, 0.0, 200u, &root, &iter) != DIANA_OK) {
    return 0;
  }
  return iter;
}

static const struct diana_benchmark_case item[] = {
    {"bisection_step", "step", NULL, 0, NULL, step, NULL},
    {"bisection", "step", NULL, 0, NULL, wrapper, NULL}};

const struct diana_benchmark_suite diana_benchmark_bisection = {
    item, sizeof item / sizeof item[0]};
