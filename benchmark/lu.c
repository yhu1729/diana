#include <stddef.h>
#include <stdlib.h>

#include "benchmark.h"
#include "diana/lu.h"

struct data {
  size_t n;
  double *a;
  double *lu;
  size_t *piv;
};

/* A has entries in [-0.5, 0.5), so partial pivoting interchanges rows. */
static void *setup(size_t n) {
  struct data *d = diana_benchmark_alloc(sizeof *d);

  d->n = n;
  d->a = diana_benchmark_alloc(n * n * sizeof *d->a);
  d->lu = diana_benchmark_alloc(n * n * sizeof *d->lu);
  d->piv = diana_benchmark_alloc(n * sizeof *d->piv);
  diana_benchmark_fill(d->a, n * n, 1u);
  return d;
}

/* A unit is a flop of the 2n^3/3 of the factorization. */
static size_t run(void *data) {
  struct data *d = data;

  if (diana_lu(d->a, d->n, d->lu, d->piv) != DIANA_OK) {
    return 0;
  }
  return 2u * d->n * d->n * d->n / 3u;
}

static void teardown(void *data) {
  struct data *d = data;

  free(d->a);
  free(d->lu);
  free(d->piv);
  free(d);
}

static const struct diana_benchmark_case item[] = {
    {"lu", "flop", diana_benchmark_matrix_size, DIANA_BENCHMARK_NSIZE, setup,
     run, teardown}};

const struct diana_benchmark_suite diana_benchmark_lu = {
    item, sizeof item / sizeof item[0]};
