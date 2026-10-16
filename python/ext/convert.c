#include <limits.h>
#include <stdint.h>

#include "module.h"

int diana_py_convert_uint(PyObject *obj, void *out) {
  PyObject *index = PyNumber_Index(obj);
  unsigned long v;

  if (index == NULL) {
    return 0;
  }
  v = PyLong_AsUnsignedLong(index);
  Py_DECREF(index);
  if (v == (unsigned long)-1 && PyErr_Occurred()) {
    return 0;
  }
  if (v > UINT_MAX) {
    PyErr_SetString(PyExc_OverflowError,
                    "unsigned int is greater than maximum");
    return 0;
  }
  *(unsigned int *)out = (unsigned int)v;
  return 1;
}

static int is_native_double(const char *format) {
  if (*format == '@' || *format == '=' ||
      *format == (PY_LITTLE_ENDIAN ? '<' : '>')) {
    ++format;
  }
  return format[0] == 'd' && format[1] == '\0';
}

int diana_py_get_samples(PyObject *obj, Py_buffer *view, Py_ssize_t min_count,
                         const char *count_message) {
  const char *format;

  if (PyObject_GetBuffer(obj, view, PyBUF_RECORDS_RO) < 0) {
    return -1;
  }
  format = view->format != NULL ? view->format : "B";
  if (!is_native_double(format) ||
      view->itemsize != (Py_ssize_t)sizeof(double)) {
    PyErr_Format(PyExc_TypeError,
                 "y must be a buffer of native float64 (format 'd'), not "
                 "format '%s'",
                 format);
    goto fail;
  }
  if (view->ndim != 1) {
    PyErr_Format(PyExc_ValueError, "y must be one-dimensional, not %d-D",
                 view->ndim);
    goto fail;
  }
  if (view->shape[0] < min_count) {
    PyErr_SetString(PyExc_ValueError, count_message);
    goto fail;
  }
  if (!PyBuffer_IsContiguous(view, 'C')) {
    PyErr_SetString(PyExc_ValueError, "y must be C-contiguous");
    goto fail;
  }
  if ((uintptr_t)view->buf % _Alignof(double) != 0u) {
    PyErr_SetString(PyExc_ValueError, "y is not aligned for float64");
    goto fail;
  }
  return 0;

fail:
  PyBuffer_Release(view);
  return -1;
}
