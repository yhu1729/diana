#define _POSIX_C_SOURCE 200809L

#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "diana/diana.h"

#define TRIAL 7
#define WORK 2e8
#define H_KERNEL 0.01
#define H_LOOP 1e-9

typedef diana_status (*euler_fn)(const double *y, const double *f, size_t d,
                                 double h, double *y_out);
typedef diana_status (*stage_fn)(const double *y, const double *k, size_t d,
                                 double h, int stage, double *y_out);
typedef diana_status (*step_fn)(const double *y, const double *k1,
                                const double *k2, const double *k3,
                                const double *k4, size_t d, double h,
                                double *y_out);

enum { EULER, STAGE, STEP, EULER_LOOP, RK4_LOOP, NCASE };

static const char *const label[NCASE] = {"euler step", "rk4 stage", "rk4 step",
                                         "euler + rhs", "rk4 + rhs"};

struct vector {
  size_t d;
  double *y;
  double *k[4];
  double *ys;
  double *out;
};

static double now(void) {
  struct timespec t;

  clock_gettime(CLOCK_MONOTONIC, &t);
  return (double)t.tv_sec * 1e9 + (double)t.tv_nsec;
}

static double *vector_new(size_t d) {
  double *p = malloc(d * sizeof *p);

  if (p == NULL) {
    fprintf(stderr, "out of memory\n");
    exit(EXIT_FAILURE);
  }
  return p;
}

static void fill(struct vector *v) {
  size_t i;
  size_t n;

  for (i = 0; i < v->d; ++i) {
    v->y[i] = (double)(i % 97u) / 97.0 - 0.5;
    for (n = 0; n < 4u; ++n) {
      v->k[n][i] = (double)((i + 13u * n) % 89u) / 89.0 - 0.5;
    }
  }
}

/* The cheapest right-hand side: y' = -y/2. */
static void rhs(const double *y, double *dy, size_t d) {
  size_t i;

  for (i = 0; i < d; ++i) {
    dy[i] = -0.5 * y[i];
  }
}

/* Nanoseconds per component of one call (or one step, for the loops). */
static double run(int c, int unchecked, struct vector *v, size_t rep) {
  euler_fn euler = unchecked ? diana_euler_step_unchecked : diana_euler_step;
  stage_fn stage = unchecked ? diana_rk4_stage_unchecked : diana_rk4_stage;
  step_fn step = unchecked ? diana_rk4_step_unchecked : diana_rk4_step;
  double *y = v->y;
  double *out = v->out;
  double *const *k = v->k;
  double *swap;
  double t0;
  size_t d = v->d;
  size_t r;
  int st = 0;

  fill(v);
  t0 = now();
  for (r = 0; r < rep; ++r) {
    switch (c) {
    case EULER:
      st |= (int)euler(y, k[0], d, H_KERNEL, out);
      break;
    case STAGE:
      st |= (int)stage(y, k[0], d, H_KERNEL, 2, out);
      break;
    case STEP:
      st |= (int)step(y, k[0], k[1], k[2], k[3], d, H_KERNEL, out);
      break;
    case EULER_LOOP:
      rhs(y, k[0], d);
      st |= (int)euler(y, k[0], d, H_LOOP, out);
      swap = y;
      y = out;
      out = swap;
      break;
    default:
      rhs(y, k[0], d);
      st |= (int)stage(y, k[0], d, H_LOOP, 2, v->ys);
      rhs(v->ys, k[1], d);
      st |= (int)stage(y, k[1], d, H_LOOP, 3, v->ys);
      rhs(v->ys, k[2], d);
      st |= (int)stage(y, k[2], d, H_LOOP, 4, v->ys);
      rhs(v->ys, k[3], d);
      st |= (int)step(y, k[0], k[1], k[2], k[3], d, H_LOOP, out);
      swap = y;
      y = out;
      out = swap;
      break;
    }
  }
  t0 = now() - t0;
  if (st != (int)DIANA_OK) {
    fprintf(stderr, "%s: a kernel failed\n", label[c]);
    exit(EXIT_FAILURE);
  }
  return t0 / ((double)rep * (double)d);
}

int main(void) {
  static const size_t size[3] = {64u, 1024u, 16384u};
  struct vector v;
  double best[2];
  double t;
  size_t s;
  size_t n;
  int c;
  int u;

#ifdef __VERSION__
  printf("compiler: %s\n", __VERSION__);
#endif
  printf("%6s  %-12s %8s %10s %6s  (ns per component, best of %d)\n", "d",
         "kernel", "checked", "unchecked", "ratio", TRIAL);
  for (s = 0; s < 3u; ++s) {
    size_t rep = (size_t)(WORK / (double)size[s]);
    v.d = size[s];
    v.y = vector_new(v.d);
    v.ys = vector_new(v.d);
    v.out = vector_new(v.d);
    for (n = 0; n < 4u; ++n) {
      v.k[n] = vector_new(v.d);
    }
    for (c = 0; c < NCASE; ++c) {
      for (u = 0; u < 2; ++u) {
        best[u] = 1e300;
        for (n = 0; n < TRIAL; ++n) {
          t = run(c, u, &v, rep);
          if (t < best[u]) {
            best[u] = t;
          }
        }
      }
      printf("%6zu  %-12s %8.3f %10.3f %6.1f\n", v.d, label[c], best[0],
             best[1], best[0] / best[1]);
    }
    free(v.y);
    free(v.ys);
    free(v.out);
    for (n = 0; n < 4u; ++n) {
      free(v.k[n]);
    }
  }
  return 0;
}
