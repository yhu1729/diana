#include <stddef.h>
#include <stdint.h>

#include "module.h"

static int overlap(const Py_buffer *a, const Py_buffer *b) {
  uintptr_t a0 = (uintptr_t)a->buf;
  uintptr_t b0 = (uintptr_t)b->buf;
  return a0 < b0 + (uintptr_t)b->len && b0 < a0 + (uintptr_t)a->len;
}

static PyObject *mod_euler_step(PyObject *Py_UNUSED(self), PyObject *args,
                                PyObject *kwds) {
  static char *kwlist[] = {"y", "f", "h", "out", NULL};
  PyObject *y;
  PyObject *f;
  PyObject *out;
  double h;
  Py_buffer vy;
  Py_buffer vf;
  Py_buffer vo;
  PyObject *ret = NULL;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "OOdO:euler_step", kwlist, &y,
                                   &f, &h, &out)) {
    return NULL;
  }
  if (diana_py_get_samples(y, &vy, "y", 0, 1,
                           "y must have at least one sample") < 0) {
    return NULL;
  }
  if (diana_py_get_samples(f, &vf, "f", 0, 1,
                           "f must have at least one sample") < 0) {
    goto release_y;
  }
  if (diana_py_get_samples(out, &vo, "out", 1, 1,
                           "out must have at least one sample") < 0) {
    goto release_f;
  }
  if (vf.shape[0] != vy.shape[0] || vo.shape[0] != vy.shape[0]) {
    PyErr_SetString(PyExc_ValueError, "y, f and out must have the same length");
    goto cleanup;
  }
  if (overlap(&vo, &vy) || overlap(&vo, &vf)) {
    PyErr_SetString(PyExc_ValueError, "out must not overlap y or f");
    goto cleanup;
  }
  st = diana_euler_step((const double *)vy.buf, (const double *)vf.buf,
                        (size_t)vy.shape[0], h, (double *)vo.buf);
  if (st != DIANA_OK) {
    diana_py_raise(st, "Euler step result is not finite");
    goto cleanup;
  }
  ret = Py_None;
  Py_INCREF(ret);

cleanup:
  PyBuffer_Release(&vo);
release_f:
  PyBuffer_Release(&vf);
release_y:
  PyBuffer_Release(&vy);
  return ret;
}

static PyMethodDef euler_method[] = {
    {"euler_step", (PyCFunction)(void (*)(void))mod_euler_step,
     METH_VARARGS | METH_KEYWORDS,
     "euler_step(y, f, h, out) -> None\n\nOne explicit Euler step "
     "out[i] = y[i] + h * f[i] over one-dimensional, C-contiguous, aligned "
     "buffers of native float64 of equal length; y and f are read in place "
     "and out, writable and separate from both, is written only on success."},
    {NULL, NULL, 0, NULL}};

int diana_py_euler_exec(PyObject *m) {
  return PyModule_AddFunctions(m, euler_method);
}
