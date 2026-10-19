#include <stddef.h>
#include <stdlib.h>

#include "benchmark.h"
#include "diana/rk4.h"

#define H_STEP 0.01
#define H_LOOP 1e-9
#define NSTEP 8u
#define STAGE 2

struct data {
  size_t d;
  double *y;
  double *k[4];
  double *out;
  double *work;
};

static void *setup(size_t n) {
  struct data *d = diana_benchmark_alloc(sizeof *d);
  size_t s;

  d->d = n;
  d->y = diana_benchmark_alloc(n * sizeof *d->y);
  diana_benchmark_fill(d->y, n, 1u);
  for (s = 0; s < 4u; ++s) {
    d->k[s] = diana_benchmark_alloc(n * sizeof *d->k[s]);
    diana_benchmark_fill(d->k[s], n, 2u + (uint64_t)s);
  }
  d->out = diana_benchmark_alloc(n * sizeof *d->out);
  d->work = diana_benchmark_alloc(5u * n * sizeof *d->work);
  return d;
}

static size_t stage(void *data) {
  struct data *d = data;

  if (diana_rk4_stage(d->y, d->k[0], d->d, H_STEP, STAGE, d->out) != DIANA_OK) {
    return 0;
  }
  return d->d;
}

static size_t stage_unchecked(void *data) {
  struct data *d = data;

  if (diana_rk4_stage_unchecked(d->y, d->k[0], d->d, H_STEP, STAGE, d->out) !=
      DIANA_OK) {
    return 0;
  }
  return d->d;
}

static size_t step(void *data) {
  struct data *d = data;

  if (diana_rk4_step(d->y, d->k[0], d->k[1], d->k[2], d->k[3], d->d, H_STEP,
                     d->out) != DIANA_OK) {
    return 0;
  }
  return d->d;
}

static size_t step_unchecked(void *data) {
  struct data *d = data;

  if (diana_rk4_step_unchecked(d->y, d->k[0], d->k[1], d->k[2], d->k[3], d->d,
                               H_STEP, d->out) != DIANA_OK) {
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

  if (diana_rk4(rhs, NULL, 0.0, H_LOOP, NSTEP, d->y, d->d, d->work, 5u * d->d,
                &done) != DIANA_OK) {
    return 0;
  }
  return d->d * NSTEP;
}

static void teardown(void *data) {
  struct data *d = data;
  size_t s;

  free(d->y);
  for (s = 0; s < 4u; ++s) {
    free(d->k[s]);
  }
  free(d->out);
  free(d->work);
  free(d);
}

static const struct diana_benchmark_case item[] = {
    {"rk4_stage", "component", diana_benchmark_vector_size,
     DIANA_BENCHMARK_NSIZE, setup, stage, teardown},
    {"rk4_stage_unchecked", "component", diana_benchmark_vector_size,
     DIANA_BENCHMARK_NSIZE, setup, stage_unchecked, teardown},
    {"rk4_step", "component", diana_benchmark_vector_size,
     DIANA_BENCHMARK_NSIZE, setup, step, teardown},
    {"rk4_step_unchecked", "component", diana_benchmark_vector_size,
     DIANA_BENCHMARK_NSIZE, setup, step_unchecked, teardown},
    {"rk4", "component", diana_benchmark_vector_size, DIANA_BENCHMARK_NSIZE,
     setup, wrapper, teardown}};

const struct diana_benchmark_suite diana_benchmark_rk4 = {
    item, sizeof item / sizeof item[0]};
