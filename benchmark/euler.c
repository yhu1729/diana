#include <stddef.h>
#include <stdlib.h>

#include "benchmark.h"
#include "diana/euler.h"

#define H_STEP 0.01
#define H_LOOP 1e-9
#define NSTEP 8u

struct data {
  size_t d;
  double *y;
  double *f;
  double *out;
  double *work;
};

static void *setup(size_t n) {
  struct data *d = diana_benchmark_alloc(sizeof *d);

  d->d = n;
  d->y = diana_benchmark_alloc(n * sizeof *d->y);
  d->f = diana_benchmark_alloc(n * sizeof *d->f);
  d->out = diana_benchmark_alloc(n * sizeof *d->out);
  d->work = diana_benchmark_alloc(2u * n * sizeof *d->work);
  diana_benchmark_fill(d->y, n, 1u);
  diana_benchmark_fill(d->f, n, 2u);
  return d;
}

static size_t step(void *data) {
  struct data *d = data;

  if (diana_euler_step(d->y, d->f, d->d, H_STEP, d->out) != DIANA_OK) {
    return 0;
  }
  return d->d;
}

static size_t step_unchecked(void *data) {
  struct data *d = data;

  if (diana_euler_step_unchecked(d->y, d->f, d->d, H_STEP, d->out) !=
      DIANA_OK) {
    return 0;
  }
  return d->d;
}

/* The cheapest right-hand side, y' = -y/2. */
static int rhs(double t, const double *y, double *dy, size_t d, void *ctx) {
  size_t i;

  (void)t;
  (void)ctx;
  for (i = 0; i < d; ++i) {
    dy[i] = -0.5 * y[i];
  }
  return 0;
}

/* NSTEP steps of the wrapper, in place; a unit is one component of one step. */
static size_t wrapper(void *data) {
  struct data *d = data;
  unsigned done;

  if (diana_euler(rhs, NULL, 0.0, H_LOOP, NSTEP, d->y, d->d, d->work, 2u * d->d,
                  &done) != DIANA_OK) {
    return 0;
  }
  return d->d * NSTEP;
}

static void teardown(void *data) {
  struct data *d = data;

  free(d->y);
  free(d->f);
  free(d->out);
  free(d->work);
  free(d);
}

static const struct diana_benchmark_case item[] = {
    {"euler_step", "component", diana_benchmark_vector_size,
     DIANA_BENCHMARK_NSIZE, setup, step, teardown},
    {"euler_step_unchecked", "component", diana_benchmark_vector_size,
     DIANA_BENCHMARK_NSIZE, setup, step_unchecked, teardown},
    {"euler", "component", diana_benchmark_vector_size, DIANA_BENCHMARK_NSIZE,
     setup, wrapper, teardown}};

const struct diana_benchmark_suite diana_benchmark_euler = {
    item, sizeof item / sizeof item[0]};
