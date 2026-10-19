#include <stddef.h>
#include <stdlib.h>

#include "benchmark.h"
#include "diana/norm.h"

struct data {
  size_t n;
  double *x;
};

static void *setup(size_t n) {
  struct data *d = diana_benchmark_alloc(sizeof *d);

  d->n = n;
  d->x = diana_benchmark_alloc(n * sizeof *d->x);
  diana_benchmark_fill(d->x, n, 1u);
  return d;
}

static size_t norm_1(void *data) {
  struct data *d = data;
  double result;

  if (diana_norm_1(d->x, d->n, &result) != DIANA_OK) {
    return 0;
  }
  return d->n;
}

static size_t norm_2(void *data) {
  struct data *d = data;
  double result;

  if (diana_norm_2(d->x, d->n, &result) != DIANA_OK) {
    return 0;
  }
  return d->n;
}

static size_t norm_inf(void *data) {
  struct data *d = data;
  double result;

  if (diana_norm_inf(d->x, d->n, &result) != DIANA_OK) {
    return 0;
  }
  return d->n;
}

static void teardown(void *data) {
  struct data *d = data;

  free(d->x);
  free(d);
}

static const struct diana_benchmark_case item[] = {
    {"norm_1", "component", diana_benchmark_vector_size, DIANA_BENCHMARK_NSIZE,
     setup, norm_1, teardown},
    {"norm_2", "component", diana_benchmark_vector_size, DIANA_BENCHMARK_NSIZE,
     setup, norm_2, teardown},
    {"norm_inf", "component", diana_benchmark_vector_size,
     DIANA_BENCHMARK_NSIZE, setup, norm_inf, teardown}};

const struct diana_benchmark_suite diana_benchmark_norm = {
    item, sizeof item / sizeof item[0]};
