#include <stddef.h>
#include <stdint.h>

#include "module.h"

static int overlap(const Py_buffer *a, const Py_buffer *b) {
  uintptr_t a0 = (uintptr_t)a->buf;
  uintptr_t b0 = (uintptr_t)b->buf;
  return a0 < b0 + (uintptr_t)b->len && b0 < a0 + (uintptr_t)a->len;
}

static PyObject *mod_rk4_stage(PyObject *Py_UNUSED(self), PyObject *args,
                               PyObject *kwds) {
  static char *kwlist[] = {"y", "k", "h", "stage", "out", NULL};
  PyObject *y;
  PyObject *k;
  PyObject *out;
  double h;
  int stage;
  Py_buffer vy;
  Py_buffer vk;
  Py_buffer vo;
  PyObject *ret = NULL;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "OOdiO:rk4_stage", kwlist, &y,
                                   &k, &h, &stage, &out)) {
    return NULL;
  }
  if (stage < 2 || stage > 4) {
    PyErr_SetString(PyExc_ValueError, "stage must be 2, 3 or 4");
    return NULL;
  }
  if (diana_py_get_samples(y, &vy, "y", 0, 1,
                           "y must have at least one sample") < 0) {
    return NULL;
  }
  if (diana_py_get_samples(k, &vk, "k", 0, 1,
                           "k must have at least one sample") < 0) {
    goto release_y;
  }
  if (diana_py_get_samples(out, &vo, "out", 1, 1,
                           "out must have at least one sample") < 0) {
    goto release_k;
  }
  if (vk.shape[0] != vy.shape[0]) {
    PyErr_SetString(PyExc_ValueError, "y and k must have the same length");
    goto cleanup;
  }
  if (vo.shape[0] != vy.shape[0]) {
    PyErr_SetString(PyExc_ValueError, "out must have the same length as y");
    goto cleanup;
  }
  if (overlap(&vo, &vy) || overlap(&vo, &vk)) {
    PyErr_SetString(PyExc_ValueError, "out must not overlap y or k");
    goto cleanup;
  }
  st = diana_rk4_stage((const double *)vy.buf, (const double *)vk.buf,
                       (size_t)vy.shape[0], h, stage, (double *)vo.buf);
  if (st != DIANA_OK) {
    diana_py_raise(st, "RK4 stage result is not finite");
    goto cleanup;
  }
  ret = Py_None;
  Py_INCREF(ret);

cleanup:
  PyBuffer_Release(&vo);
release_k:
  PyBuffer_Release(&vk);
release_y:
  PyBuffer_Release(&vy);
  return ret;
}

static PyObject *mod_rk4_step(PyObject *Py_UNUSED(self), PyObject *args,
                              PyObject *kwds) {
  static char *kwlist[] = {"y", "k1", "k2", "k3", "k4", "h", "out", NULL};
  static const char *const name[5] = {"y", "k1", "k2", "k3", "k4"};
  static const char *const empty[5] = {
      "y must have at least one sample", "k1 must have at least one sample",
      "k2 must have at least one sample", "k3 must have at least one sample",
      "k4 must have at least one sample"};
  PyObject *obj[5];
  PyObject *out;
  double h;
  Py_buffer view[5];
  Py_buffer vo;
  int got = 0;
  int have_out = 0;
  int i;
  PyObject *ret = NULL;
  diana_status st;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "OOOOOdO:rk4_step", kwlist,
                                   &obj[0], &obj[1], &obj[2], &obj[3], &obj[4],
                                   &h, &out)) {
    return NULL;
  }
  for (i = 0; i < 5; ++i) {
    if (diana_py_get_samples(obj[i], &view[i], name[i], 0, 1, empty[i]) < 0) {
      goto cleanup;
    }
    ++got;
  }
  if (diana_py_get_samples(out, &vo, "out", 1, 1,
                           "out must have at least one sample") < 0) {
    goto cleanup;
  }
  have_out = 1;
  for (i = 1; i < 5; ++i) {
    if (view[i].shape[0] != view[0].shape[0]) {
      PyErr_SetString(PyExc_ValueError,
                      "y, k1, k2, k3 and k4 must have the same length");
      goto cleanup;
    }
  }
  if (vo.shape[0] != view[0].shape[0]) {
    PyErr_SetString(PyExc_ValueError, "out must have the same length as y");
    goto cleanup;
  }
  for (i = 0; i < 5; ++i) {
    if (overlap(&vo, &view[i])) {
      PyErr_SetString(PyExc_ValueError, "out must not overlap y or a slope");
      goto cleanup;
    }
  }
  st = diana_rk4_step((const double *)view[0].buf, (const double *)view[1].buf,
                      (const double *)view[2].buf, (const double *)view[3].buf,
                      (const double *)view[4].buf, (size_t)view[0].shape[0], h,
                      (double *)vo.buf);
  if (st != DIANA_OK) {
    diana_py_raise(st, "RK4 step result is not finite");
    goto cleanup;
  }
  ret = Py_None;
  Py_INCREF(ret);

cleanup:
  if (have_out) {
    PyBuffer_Release(&vo);
  }
  for (i = 0; i < got; ++i) {
    PyBuffer_Release(&view[i]);
  }
  return ret;
}

static PyMethodDef rk4_method[] = {
    {"rk4_stage", (PyCFunction)(void (*)(void))mod_rk4_stage,
     METH_VARARGS | METH_KEYWORDS,
     "rk4_stage(y, k, h, stage, out) -> None\n\nThe RK4 stage point "
     "out[i] = y[i] + c * k[i], c = 0.5 * h for stage 2 or 3 and c = h for "
     "stage 4, over one-dimensional, C-contiguous, aligned buffers of native "
     "float64 of equal length; y and k are read in place and out, writable "
     "and separate from both, is written only on success."},
    {"rk4_step", (PyCFunction)(void (*)(void))mod_rk4_step,
     METH_VARARGS | METH_KEYWORDS,
     "rk4_step(y, k1, k2, k3, k4, h, out) -> None\n\nThe RK4 step "
     "out[i] = y[i] + h * ((k1[i] + k4[i]) + 2 * (k2[i] + k3[i])) / 6 over "
     "one-dimensional, C-contiguous, aligned buffers of native float64 of "
     "equal length; the inputs are read in place and out, writable and "
     "separate from all of them, is written only on success."},
    {NULL, NULL, 0, NULL}};

int diana_py_rk4_exec(PyObject *m) {
  return PyModule_AddFunctions(m, rk4_method);
}
