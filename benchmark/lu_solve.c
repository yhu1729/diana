#include <stddef.h>
#include <stdlib.h>

#include "benchmark.h"
#include "diana/lu.h"
#include "diana/lu_solve.h"

struct data {
  size_t n;
  double *lu;
  size_t *piv;
  double *b;
  double *x;
};

/* The factors of the matrix the lu case factors. */
static void *setup(size_t n) {
  struct data *d = diana_benchmark_alloc(sizeof *d);
  double *a = diana_benchmark_alloc(n * n * sizeof *a);
  diana_status st;

  d->n = n;
  d->lu = diana_benchmark_alloc(n * n * sizeof *d->lu);
  d->piv = diana_benchmark_alloc(n * sizeof *d->piv);
  d->b = diana_benchmark_alloc(n * sizeof *d->b);
  d->x = diana_benchmark_alloc(n * sizeof *d->x);
  diana_benchmark_fill(a, n * n, 1u);
  st = diana_lu(a, n, d->lu, d->piv);
  free(a);
  if (st != DIANA_OK) {
    return NULL;
  }
  diana_benchmark_fill(d->b, n, 2u);
  return d;
}

/* A unit is a flop of the 2n^2 of the two triangular solves. */
static size_t run(void *data) {
  struct data *d = data;

  if (diana_lu_solve(d->lu, d->piv, d->n, d->b, d->x) != DIANA_OK) {
    return 0;
  }
  return 2u * d->n * d->n;
}

static void teardown(void *data) {
  struct data *d = data;

  free(d->lu);
  free(d->piv);
  free(d->b);
  free(d->x);
  free(d);
}

static const struct diana_benchmark_case item[] = {
    {"lu_solve", "flop", diana_benchmark_matrix_size, DIANA_BENCHMARK_NSIZE,
     setup, run, teardown}};

const struct diana_benchmark_suite diana_benchmark_lu_solve = {
    item, sizeof item / sizeof item[0]};
