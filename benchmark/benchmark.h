#ifndef DIANA_BENCHMARK_H
#define DIANA_BENCHMARK_H

#include <stddef.h>
#include <stdint.h>

/* One timed kernel: setup(n) allocates and fills its inputs, run makes one
   call (or one solve) and returns the units of work it did, 0 on a failed
   call, and teardown frees. setup and teardown may be NULL. A NULL size list
   means one run with no size. */
struct diana_benchmark_case {
  const char *name;
  const char *unit;
  const size_t *size;
  size_t nsize;
  void *(*setup)(size_t n);
  size_t (*run)(void *data);
  void (*teardown)(void *data);
};

struct diana_benchmark_suite {
  const struct diana_benchmark_case *item;
  size_t count;
};

#define DIANA_BENCHMARK_NSIZE 3u

extern const size_t diana_benchmark_vector_size[DIANA_BENCHMARK_NSIZE];
extern const size_t diana_benchmark_sample_size[DIANA_BENCHMARK_NSIZE];
extern const size_t diana_benchmark_matrix_size[DIANA_BENCHMARK_NSIZE];

/* harness.c */
void *diana_benchmark_alloc(size_t size);
void diana_benchmark_fill(double *x, size_t n, uint64_t seed);
void diana_benchmark_spd(double *a, size_t n);
double diana_benchmark_time(const struct diana_benchmark_case *c, size_t n,
                            double *unit_per_call);

/* one suite per method */
extern const struct diana_benchmark_suite diana_benchmark_bisection;
extern const struct diana_benchmark_suite diana_benchmark_newton;
extern const struct diana_benchmark_suite diana_benchmark_trapezoidal;
extern const struct diana_benchmark_suite diana_benchmark_simpson;
extern const struct diana_benchmark_suite diana_benchmark_euler;
extern const struct diana_benchmark_suite diana_benchmark_rk4;
extern const struct diana_benchmark_suite diana_benchmark_cholesky;
extern const struct diana_benchmark_suite diana_benchmark_substitution;
extern const struct diana_benchmark_suite diana_benchmark_lu;
extern const struct diana_benchmark_suite diana_benchmark_lu_solve;
extern const struct diana_benchmark_suite diana_benchmark_norm;
extern const struct diana_benchmark_suite diana_benchmark_axpy;

#endif
