#include "module.h"

PyObject *diana_py_version(PyObject *Py_UNUSED(self),
                           PyObject *Py_UNUSED(ignored)) {
  return PyUnicode_FromString(diana_version());
}
