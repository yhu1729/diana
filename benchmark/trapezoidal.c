#include <stddef.h>
#include <stdlib.h>

#include "benchmark.h"
#include "diana/trapezoidal.h"

#define H 1e-3

struct data {
  size_t n;
  double *y;
};

static void *setup(size_t n) {
  struct data *d = diana_benchmark_alloc(sizeof *d);

  d->n = n;
  d->y = diana_benchmark_alloc(n * sizeof *d->y);
  diana_benchmark_fill(d->y, n, 1u);
  return d;
}

static size_t run(void *data) {
  struct data *d = data;
  double result;

  if (diana_trapezoidal(d->y, d->n, H, &result) != DIANA_OK) {
    return 0;
  }
  return d->n;
}

static void teardown(void *data) {
  struct data *d = data;

  free(d->y);
  free(d);
}

static const struct diana_benchmark_case item[] = {
    {"trapezoidal", "sample", diana_benchmark_sample_size,
     DIANA_BENCHMARK_NSIZE, setup, run, teardown}};

const struct diana_benchmark_suite diana_benchmark_trapezoidal = {
    item, sizeof item / sizeof item[0]};
