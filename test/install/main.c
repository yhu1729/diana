#include <stdio.h>
#include <string.h>

#include "diana/diana.h"

static double sq_minus_2(double x, void *ctx) {
  (void)ctx;
  return x * x - 2.0;
}

int main(void) {
  double root = 0.0;
  unsigned iter = 0;
  diana_status st =
      diana_bisect(sq_minus_2, NULL, 0.0, 2.0, 1e-12, 100u, &root, &iter);
  double err = root - 1.4142135623730951;
  if (st != DIANA_OK || err < -1e-12 || err > 1e-12) {
    fprintf(stderr, "diana_bisect: %s, root %.17g\n", diana_status_str(st),
            root);
    return 1;
  }
  if (strcmp(diana_version(), DIANA_VERSION_STRING) != 0) {
    fprintf(stderr, "header %s, library %s\n", DIANA_VERSION_STRING,
            diana_version());
    return 1;
  }
  printf("find_package(diana): ok\n");
  return 0;
}
