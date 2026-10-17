#include <stdint.h>

#include "module.h"

static inline int is_native_double(const char *format) {
  if (*format == '@' || *format == '=' ||
      *format == (PY_LITTLE_ENDIAN ? '<' : '>')) {
    ++format;
  }
  return format[0] == 'd' && format[1] == '\0';
}

int diana_py_get_samples(PyObject *obj, Py_buffer *view, const char *name,
                         int writable, Py_ssize_t min_count,
                         const char *count_message) {
  const char *format;

  if (PyObject_GetBuffer(obj, view,
                         writable ? PyBUF_RECORDS : PyBUF_RECORDS_RO) < 0) {
    return -1;
  }
  format = view->format != NULL ? view->format : "B";
  if (!is_native_double(format) ||
      view->itemsize != (Py_ssize_t)sizeof(double)) {
    PyErr_Format(PyExc_TypeError,
                 "%s must be a buffer of native float64 (format 'd'), not "
                 "format '%s'",
                 name, format);
    goto fail;
  }
  if (view->ndim != 1) {
    PyErr_Format(PyExc_ValueError, "%s must be one-dimensional, not %d-D", name,
                 view->ndim);
    goto fail;
  }
  if (view->shape[0] < min_count) {
    PyErr_SetString(PyExc_ValueError, count_message);
    goto fail;
  }
  if (!PyBuffer_IsContiguous(view, 'C')) {
    PyErr_Format(PyExc_ValueError, "%s must be C-contiguous", name);
    goto fail;
  }
  if ((uintptr_t)view->buf % _Alignof(double) != 0u) {
    PyErr_Format(PyExc_ValueError, "%s is not aligned for float64", name);
    goto fail;
  }
  return 0;

fail:
  PyBuffer_Release(view);
  return -1;
}
