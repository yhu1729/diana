#include "diana/diana.h"

const char *diana_status_str(diana_status s) {
  switch (s) {
  case DIANA_OK:
    return "ok";
  case DIANA_CONTINUE:
    return "continue";
  case DIANA_ERR_ARG:
    return "invalid argument";
  case DIANA_ERR_BRACKET:
    return "no sign change in bracket";
  case DIANA_ERR_MAXITER:
    return "iteration limit reached";
  case DIANA_ERR_SINGULAR:
    return "zero derivative or pivot";
  }
  return "unknown status";
}

const char *diana_version(void) { return DIANA_VERSION_STRING; }
