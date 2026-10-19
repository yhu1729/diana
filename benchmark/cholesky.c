#include <stddef.h>
#include <stdlib.h>

#include "benchmark.h"
#include "diana/cholesky.h"

struct data {
  size_t n;
  double *a;
  double *l;
};

static void *setup(size_t n) {
  struct data *d = diana_benchmark_alloc(sizeof *d);

  d->n = n;
  d->a = diana_benchmark_alloc(n * n * sizeof *d->a);
  d->l = diana_benchmark_alloc(n * n * sizeof *d->l);
  diana_benchmark_spd(d->a, n);
  return d;
}

/* A unit is a flop of the n^3/3 of the factorization. */
static size_t run(void *data) {
  struct data *d = data;

  if (diana_cholesky(d->a, d->n, d->l) != DIANA_OK) {
    return 0;
  }
  return d->n * d->n * d->n / 3u;
}

static void teardown(void *data) {
  struct data *d = data;

  free(d->a);
  free(d->l);
  free(d);
}

static const struct diana_benchmark_case item[] = {
    {"cholesky", "flop", diana_benchmark_matrix_size, DIANA_BENCHMARK_NSIZE,
     setup, run, teardown}};

const struct diana_benchmark_suite diana_benchmark_cholesky = {
    item, sizeof item / sizeof item[0]};
