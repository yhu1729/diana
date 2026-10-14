#ifndef DIANA_TEST_CHECK_H
#define DIANA_TEST_CHECK_H

#include <stdio.h>

static int diana_check_fail_count = 0;

#define CHECK(cond)                                                            \
  do {                                                                         \
    if (!(cond)) {                                                             \
      diana_check_fail_count++;                                                \
      fprintf(stderr, "%s:%d: CHECK failed: %s\n", __FILE__, __LINE__, #cond); \
    }                                                                          \
  } while (0)

#define CHECK_EQ_STATUS(got, want)                                             \
  do {                                                                         \
    diana_status diana_check_got = (got);                                      \
    if (diana_check_got != (want)) {                                           \
      diana_check_fail_count++;                                                \
      fprintf(stderr, "%s:%d: status %s, want %s\n", __FILE__, __LINE__,       \
              diana_status_str(diana_check_got), diana_status_str(want));      \
    }                                                                          \
  } while (0)

static int check_report(const char *name) {
  if (diana_check_fail_count != 0) {
    fprintf(stderr, "%s: %d failure(s)\n", name, diana_check_fail_count);
    return 1;
  }
  printf("%s: ok\n", name);
  return 0;
}

#endif
