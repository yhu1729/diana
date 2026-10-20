#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "benchmark.h"

static const struct diana_benchmark_suite *const suite[] = {
    &diana_benchmark_bisection,   &diana_benchmark_newton,
    &diana_benchmark_trapezoidal, &diana_benchmark_simpson,
    &diana_benchmark_euler,       &diana_benchmark_rk4,
    &diana_benchmark_cholesky,    &diana_benchmark_substitution,
    &diana_benchmark_lu,          &diana_benchmark_lu_solve,
    &diana_benchmark_norm,        &diana_benchmark_axpy};

#define NSUITE (sizeof suite / sizeof suite[0])

static void usage(FILE *out) {
  fprintf(out, "usage: benchmark [--list] [name...]\n"
               "  times every case, or those whose name starts with a name "
               "given\n");
}

static int selected(const char *name, int argc, char **argv) {
  int i;

  if (argc == 0) {
    return 1;
  }
  for (i = 0; i < argc; ++i) {
    if (strncmp(name, argv[i], strlen(argv[i])) == 0) {
      return 1;
    }
  }
  return 0;
}

static void row(const struct diana_benchmark_case *c, size_t n) {
  double unit;
  double call = diana_benchmark_time(c, n, &unit);

  if (c->size == NULL) {
    printf("%-26s %6s", c->name, "-");
  } else {
    printf("%-26s %6zu", c->name, n);
  }
  printf(" %12.1f %9.3f  %s\n", call, call / unit, c->unit);
  fflush(stdout);
}

int main(int argc, char **argv) {
  const struct diana_benchmark_case *c;
  size_t s;
  size_t i;
  size_t k;
  int list = 0;
  int found = 0;

  if (argc > 1 && strcmp(argv[1], "--list") == 0) {
    list = 1;
    --argc;
    ++argv;
  } else if (argc > 1 && argv[1][0] == '-') {
    usage(stderr);
    return 2;
  }
  --argc;
  ++argv;
  if (!list) {
#ifdef __VERSION__
    printf("compiler: %s\n", __VERSION__);
#endif
    printf("best of 7 trials of at least 50 ms each; unit: a component, a "
           "sample, a step or a flop\n");
    printf("%-26s %6s %12s %9s  %s\n", "kernel", "n", "ns/call", "ns/unit",
           "unit");
  }
  for (s = 0; s < NSUITE; ++s) {
    for (i = 0; i < suite[s]->count; ++i) {
      c = &suite[s]->item[i];
      if (!selected(c->name, argc, argv)) {
        continue;
      }
      found = 1;
      if (list) {
        printf("%s\n", c->name);
      } else if (c->size == NULL) {
        row(c, 0);
      } else {
        for (k = 0; k < c->nsize; ++k) {
          row(c, c->size[k]);
        }
      }
    }
  }
  if (!found) {
    fprintf(stderr, "benchmark: no case matches\n");
    return 2;
  }
  return 0;
}
