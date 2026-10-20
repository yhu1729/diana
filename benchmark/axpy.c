#include <stddef.h>
#include <stdlib.h>

#include "benchmark.h"
#include "diana/axpy.h"

/* Small enough that y, updated in place on every call, stays far from
   overflow over a whole run. */
#define A 1e-9

struct data {
  size_t n;
  double *x;
  double *y;
};

static void *setup(size_t n) {
  struct data *d = diana_benchmark_alloc(sizeof *d);

  d->n = n;
  d->x = diana_benchmark_alloc(n * sizeof *d->x);
  d->y = diana_benchmark_alloc(n * sizeof *d->y);
  diana_benchmark_fill(d->x, n, 1u);
  diana_benchmark_fill(d->y, n, 2u);
  return d;
}

static size_t axpy(void *data) {
  struct data *d = data;

  if (diana_axpy(A, d->x, d->n, d->y) != DIANA_OK) {
    return 0;
  }
  return d->n;
}

static size_t axpy_unchecked(void *data) {
  struct data *d = data;

  if (diana_axpy_unchecked(A, d->x, d->n, d->y) != DIANA_OK) {
    return 0;
  }
  return d->n;
}

static void teardown(void *data) {
  struct data *d = data;

  free(d->x);
  free(d->y);
  free(d);
}

static const struct diana_benchmark_case item[] = {
    {"axpy", "component", diana_benchmark_vector_size, DIANA_BENCHMARK_NSIZE,
     setup, axpy, teardown},
    {"axpy_unchecked", "component", diana_benchmark_vector_size,
     DIANA_BENCHMARK_NSIZE, setup, axpy_unchecked, teardown}};

const struct diana_benchmark_suite diana_benchmark_axpy = {
    item, sizeof item / sizeof item[0]};
