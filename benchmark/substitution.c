#include <stddef.h>
#include <stdlib.h>

#include "benchmark.h"
#include "diana/cholesky.h"
#include "diana/substitution.h"

struct data {
  size_t n;
  double *l;
  double *b;
  double *x;
};

/* L is the Cholesky factor of diana_benchmark_spd, so the solutions stay
   bounded by |b|. */
static void *setup(size_t n) {
  struct data *d = diana_benchmark_alloc(sizeof *d);
  double *a = diana_benchmark_alloc(n * n * sizeof *a);
  diana_status st;

  d->n = n;
  d->l = diana_benchmark_alloc(n * n * sizeof *d->l);
  d->b = diana_benchmark_alloc(n * sizeof *d->b);
  d->x = diana_benchmark_alloc(n * sizeof *d->x);
  diana_benchmark_spd(a, n);
  st = diana_cholesky(a, n, d->l);
  free(a);
  if (st != DIANA_OK) {
    return NULL;
  }
  diana_benchmark_fill(d->b, n, 1u);
  return d;
}

/* A unit is a flop of the n^2 of a triangular solve. */
static size_t forward(void *data) {
  struct data *d = data;

  if (diana_forward_substitution(d->l, d->n, d->b, d->x) != DIANA_OK) {
    return 0;
  }
  return d->n * d->n;
}

static size_t transpose(void *data) {
  struct data *d = data;

  if (diana_transpose_substitution(d->l, d->n, d->b, d->x) != DIANA_OK) {
    return 0;
  }
  return d->n * d->n;
}

static void teardown(void *data) {
  struct data *d = data;

  free(d->l);
  free(d->b);
  free(d->x);
  free(d);
}

static const struct diana_benchmark_case item[] = {
    {"forward_substitution", "flop", diana_benchmark_matrix_size,
     DIANA_BENCHMARK_NSIZE, setup, forward, teardown},
    {"transpose_substitution", "flop", diana_benchmark_matrix_size,
     DIANA_BENCHMARK_NSIZE, setup, transpose, teardown}};

const struct diana_benchmark_suite diana_benchmark_substitution = {
    item, sizeof item / sizeof item[0]};
