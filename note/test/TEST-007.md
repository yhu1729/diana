---
id: TEST-007
title: Bisection tests pin step counts, exact hits and immediate convergence
kind: fact
path:
  - test/c/test_bisection.c
  - test/python/test_bisection.py
related: [TEST-008, TEST-009]
---
The bisection tests pin the step counts that follow from halving, and the cases where the root is
hit exactly or the initial bracket has already converged.

- `x*x - 2` on `[0, 2]` with `tol = 1e-12` takes 41 steps, `ceil(log2(2 / 1e-12))`. After every
  step the C test checks `a <= b`, that the bracket is nested in the previous one, the sign change,
  and that the width is at most half the previous width plus `DBL_EPSILON * b`.
- The wrapper `diana_bisection` evaluates `f(a)`, `f(b)`, then `f` once per step, in that order
  (`0, 2, 1` first): `n == iter + 2`, with `iter = ceil(log2(2 / 1e-6)) = 21` for `tol = 1e-6`.
  Python checks that the callback sees `0.0, 1.0, 0.5` first, all `float`.
- `tol = 0` stops at adjacent or equal endpoints: the wrapper's root for `x*x - 2` is within one
  ulp of `sqrt(2)` after at most 64 steps; for root `1/3` on `[0, 1]` the final `b` is
  `nextafter(a, +inf)` (or `a == b`) and the estimate is within `DBL_EPSILON`.
- Exact hits: root `0.5` on `[0, 1]` is the first midpoint (`iter == 1`, root exactly 0.5); a root
  at an endpoint is reported by `init` with no step (`iter == 0` and root 0 for `c = 0`).
- `init` returns `DIANA_OK` without a step when `tol >= b - a` (width 1 reported), or when
  `tol = 0` and the endpoints are adjacent: above 1 the midpoint rounds onto `b`, just below 1
  onto `a`. A bracket three doubles wide below 1 takes exactly one step, whichever side moves.
- Range: `[-DBL_MAX/2, DBL_MAX/2]` is accepted with midpoint 0, `[DBL_MAX/4, DBL_MAX/2]` gets a
  finite midpoint strictly inside, and `[-DBL_MAX, DBL_MAX]` is `DIANA_ERR_ARG`.
