---
id: PYTHON-004
title: Extension vector functions write into a caller-supplied out buffer
kind: fact
path:
  - python/ext/euler_step.c
  - python/ext/rk4_stage.c
  - python/ext/rk4_step.c
  - python/ext/cholesky.c
  - python/ext/substitution.c
  - python/ext/lu.c
  - python/ext/lu_solve.c
  - python/ext/module.h
  - python/src/diana/_euler.py
  - python/src/diana/_rk4.py
related: [PYTHON-002, KERNEL-002, API-004, API-020]
---
`diana._diana.euler_step(y, f, h, out)`, `rk4_stage(y, k, h, stage, out)`,
`rk4_step(y, k1, k2, k3, k4, h, out)`, `cholesky(a, out)`, `forward_substitution(lower, b, out)`,
`back_substitution(lower, b, out)` and `lu_solve(lu, piv, b, out)` write the result into `out`
and return `None`, and
`lu(a, out)` writes the factor into `out` and returns the pivot rows as a list (API-033); the public
drivers allocate a fresh zeroed `array.array("d")` of the length of `y` (or `a`, or `b`), pass it
as `out`, and return it.

Check order in the extension, each failure raising before the kernel runs:
1. Argument parsing; `rk4_stage` then rejects a `stage` outside 2 to 4 (`ValueError`).
2. `diana_py_get_array` on each input in order, then on `out` with `PyBUF_RECORDS`: a read-only
   exporter such as `bytes` raises `BufferError`, a non-buffer `TypeError`, then the usual
   format, dimension, length >= 1, contiguity and alignment checks (API-020).
3. Equal lengths: inputs against `y` (`y and f must have the same length`, …), then `out`
   (`out must have the same length as y`).
4. Overlap: `diana_py_overlap` compares the byte ranges `[buf, buf + len)` of `out` and each input
   and raises `ValueError` (`out must not overlap y or f`, `… y or k`, `… y or a slope`) for any
   shared byte, including `out` being an input. Inputs may alias each other.
5. The C kernel; its error status goes through `diana_py_raise` (`ValueError`;
   `FloatOverflowError` from every function but `cholesky`; `SingularError` from `cholesky`, the
   substitution functions, `lu` and `lu_solve`). `out` is untouched on every failure, the C
   kernel's own guarantee (KERNEL-002), except after `SingularError` from `cholesky` (API-028)
   or `lu`, and `FloatOverflowError` from a substitution (API-030), `lu` (API-032) or
   `lu_solve` (API-034), whose public drivers then discard `out`. `cholesky` checks the square
   length before the lengths (API-029), the substitution functions `len(lower) == len(b)**2`
   (API-031), `lu_solve` `len(lu) == len(b)**2` and converts `piv` after the overlap check
   (API-035).

The drivers never trigger steps 2 to 4 for `out`, since their array is new, writable and the
length of `y`. Tests: `test_extension_checks_out` in `test/python/test_euler.py` and
`test/python/test_rk4.py`.
