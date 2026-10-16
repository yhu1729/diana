#include "module.h"

static PyObject *mod_version(PyObject *Py_UNUSED(self),
                             PyObject *Py_UNUSED(ignored)) {
  return PyUnicode_FromString(diana_version());
}

static PyMethodDef mod_method[] = {{"version", mod_version, METH_NOARGS,
                                    "Version string of the linked C library."},
                                   {NULL, NULL, 0, NULL}};

static struct PyModuleDef mod_def = {
    PyModuleDef_HEAD_INIT,
    .m_name = "diana._diana",
    .m_doc = "C extension for Diana: formally verified numerical methods.",
    .m_size = -1,
    .m_methods = mod_method,
};

PyMODINIT_FUNC PyInit__diana(void) {
  PyObject *m = PyModule_Create(&mod_def);
  if (m == NULL) {
    return NULL;
  }
  if (diana_py_status_exec(m) < 0 || diana_py_bisection_exec(m) < 0 ||
      diana_py_euler_exec(m) < 0 || diana_py_simpson_exec(m) < 0 ||
      diana_py_trapezoidal_exec(m) < 0) {
    Py_DECREF(m);
    return NULL;
  }
  return m;
}
