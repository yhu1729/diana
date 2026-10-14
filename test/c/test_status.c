#include <string.h>

#include "check.h"
#include "diana/diana.h"

int main(void) {
  CHECK(strcmp(diana_status_str(DIANA_OK), "ok") == 0);
  CHECK(strcmp(diana_status_str(DIANA_CONTINUE), "continue") == 0);
  CHECK(diana_status_str(DIANA_ERR_ARG) != (const char *)0);
  CHECK(diana_status_str(DIANA_ERR_BRACKET) != (const char *)0);
  CHECK(diana_status_str(DIANA_ERR_MAXITER) != (const char *)0);
  CHECK(diana_status_str((diana_status)12345) != (const char *)0);
  CHECK(strcmp(diana_version(), DIANA_VERSION_STRING) == 0);
  return check_report("status");
}
