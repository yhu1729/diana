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
