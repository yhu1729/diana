#ifndef DIANA_STATUS_H
#define DIANA_STATUS_H

#ifdef __cplusplus
extern "C" {
#endif

typedef enum diana_status {
  DIANA_OK = 0,
  DIANA_CONTINUE = 1,
  DIANA_ERR_ARG = -1,
  DIANA_ERR_BRACKET = -2,
  DIANA_ERR_MAXITER = -3,
  DIANA_ERR_SINGULAR = -4,
  DIANA_ERR_OVERFLOW = -5
} diana_status;

const char *diana_status_str(diana_status s);

#ifdef __cplusplus
}
#endif

#endif
