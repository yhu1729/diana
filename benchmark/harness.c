#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "benchmark.h"

#define TRIAL 7u
#define TRIAL_MIN_NS 5e7

const size_t diana_benchmark_vector_size[DIANA_BENCHMARK_NSIZE] = {64u, 1024u,
                                                                   16384u};
const size_t diana_benchmark_sample_size[DIANA_BENCHMARK_NSIZE] = {65u, 1025u,
                                                                   16385u};
const size_t diana_benchmark_matrix_size[DIANA_BENCHMARK_NSIZE] = {16u, 64u,
                                                                   256u};

void *diana_benchmark_alloc(size_t size) {
  void *p = malloc(size);

  if (p == NULL) {
    fprintf(stderr, "benchmark: out of memory\n");
    exit(EXIT_FAILURE);
  }
  return p;
}

/* splitmix64 values in [-0.5, 0.5), the same for a given seed everywhere. */
void diana_benchmark_fill(double *x, size_t n, uint64_t seed) {
  size_t i;
  uint64_t z;

  for (i = 0; i < n; ++i) {
    seed += UINT64_C(0x9e3779b97f4a7c15);
    z = seed;
    z = (z ^ (z >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
    z = (z ^ (z >> 27)) * UINT64_C(0x94d049bb133111eb);
    z ^= z >> 31;
    x[i] = (double)(z >> 11) * 0x1p-53 - 0.5;
  }
}

/* The symmetric positive definite A[i, j] = 1/(1 + |i - j|) + n [i = j],
   column-major; diagonally dominant, so well conditioned at every n. */
void diana_benchmark_spd(double *a, size_t n) {
  size_t i;
  size_t j;
  size_t k;

  for (j = 0; j < n; ++j) {
    for (i = 0; i < n; ++i) {
      k = i > j ? i - j : j - i;
      a[i + j * n] = 1.0 / (1.0 + (double)k) + (i == j ? (double)n : 0.0);
    }
  }
}

static double now_ns(void) {
  struct timespec t;

  clock_gettime(CLOCK_MONOTONIC, &t);
  return (double)t.tv_sec * 1e9 + (double)t.tv_nsec;
}

/* Time rep calls; returns the elapsed nanoseconds and adds the units done. */
static double trial(const struct diana_benchmark_case *c, void *data,
                    size_t rep, size_t *unit) {
  size_t r;
  size_t u;
  size_t total = 0;
  double t0 = now_ns();

  for (r = 0; r < rep; ++r) {
    u = c->run(data);
    if (u == 0) {
      fprintf(stderr, "benchmark: %s: a call failed\n", c->name);
      exit(EXIT_FAILURE);
    }
    total += u;
  }
  t0 = now_ns() - t0;
  *unit += total;
  return t0;
}

/* Best of TRIAL trials, each of enough calls to last TRIAL_MIN_NS: the
   nanoseconds of one call, and the units one call does. */
double diana_benchmark_time(const struct diana_benchmark_case *c, size_t n,
                            double *unit_per_call) {
  void *data = c->setup != NULL ? c->setup(n) : NULL;
  size_t rep = 1;
  size_t unit = 0;
  size_t call = 0;
  double best;
  double t;
  unsigned i;

  for (;;) {
    t = trial(c, data, rep, &unit);
    call += rep;
    if (t >= TRIAL_MIN_NS) {
      break;
    }
    rep *= 2;
  }
  best = t;
  for (i = 1; i < TRIAL; ++i) {
    t = trial(c, data, rep, &unit);
    call += rep;
    if (t < best) {
      best = t;
    }
  }
  if (c->teardown != NULL) {
    c->teardown(data);
  }
  *unit_per_call = (double)unit / (double)call;
  return best / (double)rep;
}
