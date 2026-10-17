---
id: TEST-008
title: Bisection worst case of 2098 steps and the Python default max_iter 2100
kind: fact
path:
  - test/c/test_bisection.c
  - test/python/test_bisection.py
  - python/ext/bisection_init.c
  - python/src/diana/_bisection.py
  - spec/bisection.md
related: [TEST-007, COMPILER-006]
---
With `tol = 0`, root `DBL_TRUE_MIN` and bracket `[-DBL_MAX/2, DBL_MAX/2]`, bisection takes 2098
steps, the worst case found for any bracket the kernel accepts. The default `max_iter = 2100` of
Python's `Bisection` and `bisection` is chosen to cover it; the C API has no default.

- `test_worst_case_step_count` in `test/c/test_bisection.c` runs it with `max_iter = 2100` and
  requires `DIANA_OK`, `iter == 2098` and the root inside the final bracket.
  `test_default_max_iter_worst_case` in `test/python/test_bisection.py` repeats it with the
  default (asserted to be 2100) and checks that `diana.bisection` finds the root to within
  `DBL_TRUE_MIN`. The compiler corpus prints this run and its mirror (root `-DBL_TRUE_MIN`) step
  by step.
- Rough count: the width falls from about `2^1024` to the subnormal spacing `2^-1074`, 2098
  halvings. Rounded midpoints do not halve the width exactly, so this is no proof.
- BISECTION-B4 proves termination with a loose bound (`lattice`, up to `2^1075`), not 2098.
  `spec/bisection.md` ("What B4 does not say") records the closed form `emax - emin + p + 1`
  found by exhaustive search over small binary formats, `1022 - (-1022) + 53 + 1 = 2098` for
  `|a|, |b| <= DBL_MAX/2`, as evidence only. These tests are what pin the constant.
- The default is written twice: `max_iter = 2100u` in `python/ext/bisection_init.c` and
  `max_iter: int = 2100` in `python/src/diana/_bisection.py`.
