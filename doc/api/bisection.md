# Bisection

Bisection finds a root of a continuous function `f` on an interval `[a, b]` where `f(a)` and
`f(b)` have opposite signs. Each step evaluates `f` at the midpoint and keeps the half that still
brackets a root, so the bracket halves every step and the method always converges, if slowly.
Shared conventions are in the [API overview](overview.md).

## C

`#include <diana/bisection.h>`. The kernel is a state machine: you evaluate `f` at the point the
state asks for, `s.x`, and pass the value back.

- `diana_bisection_init(&s, a, b, f(a), f(b), tol, max_iter)` starts from the bracket. It returns
  `DIANA_CONTINUE` with the first midpoint in `s.x`, or `DIANA_OK` when there is nothing to do: an
  endpoint is a root, or the bracket is already within `tol` or too narrow to split.
- `diana_bisection_step(&s, f(s.x))` keeps the half that brackets a root. It returns
  `DIANA_CONTINUE` with the next point in `s.x`, `DIANA_OK` once the bracket is no wider than
  `tol` (or `f(s.x)` is zero, or no double is left between the endpoints), or
  `DIANA_ERR_MAXITER` after `max_iter` steps. Call it only after `DIANA_CONTINUE`.
- `diana_bisection_result(&s, &root, &width)` gives the midpoint of the bracket and its width.
  Either output may be `NULL`. Use it for the answer: after `DIANA_OK`, `s.x` is not necessarily
  the midpoint.

`init` returns `DIANA_ERR_ARG` for a `NULL` state, a NaN or infinite argument, `a > b`, `|a|` or
`|b|` above `DBL_MAX/2`, `tol < 0` or `max_iter == 0`, and `DIANA_ERR_BRACKET` when `f(a)` and
`f(b)` have the same sign; `step` returns `DIANA_ERR_ARG` for a non-finite `f(s.x)`. A rejected
call leaves the state unchanged. Finding `√2` as the root of `x² − 2` in `[0, 2]`:

```c
#include <stdio.h>

#include <diana/bisection.h>

static double f(double x) { return x * x - 2.0; }

int main(void) {
  diana_bisection_state s;
  double root, width;
  diana_status st =
      diana_bisection_init(&s, 0.0, 2.0, f(0.0), f(2.0), 1e-12, 100u);
  while (st == DIANA_CONTINUE) {
    st = diana_bisection_step(&s, f(s.x));
  }
  if (st != DIANA_OK) {
    fprintf(stderr, "bisection: %s\n", diana_status_str(st));
    return 1;
  }
  diana_bisection_result(&s, &root, &width);
  printf("root %.17g, width %.3g, %u steps\n", root, width, s.iter);
  return 0;
}
```

```text
root 1.4142135623728791, width 9.09e-13, 41 steps
```

The state `diana_bisection_state` is a plain struct; read its fields, but change them only
through the functions:

| Field | Meaning |
|---|---|
| `a`, `b` | current bracket, `a <= b` |
| `fa`, `fb` | `f(a)`, `f(b)` |
| `x` | point at which to evaluate `f` next |
| `tol` | stop once `b - a <= tol` |
| `iter`, `max_iter` | steps taken so far, and the limit |

With `tol = 0` the loop runs until the endpoints are adjacent doubles. Because you see every
point before `f` is evaluated there, you can trace the run; after `DIANA_ERR_MAXITER` the state
still holds a valid bracket, so `diana_bisection_result` reports the estimate reached so far:

```c
#include <stdio.h>

#include <diana/bisection.h>

int main(void) {
  diana_bisection_state s;
  double root, width;
  diana_status st = diana_bisection_init(&s, 0.0, 2.0, -2.0, 2.0, 0.0, 4u);
  while (st == DIANA_CONTINUE) {
    printf("step %u: [%g, %g], evaluate at %g\n", s.iter, s.a, s.b, s.x);
    st = diana_bisection_step(&s, s.x * s.x - 2.0);
  }
  diana_bisection_result(&s, &root, &width);
  printf("%s after %u steps: root %g, width %g\n", diana_status_str(st), s.iter,
         root, width);
  return st == DIANA_OK ? 0 : 1;
}
```

```text
step 0: [0, 2], evaluate at 1
step 1: [1, 2], evaluate at 1.5
step 2: [1, 1.5], evaluate at 1.25
step 3: [1.25, 1.5], evaluate at 1.375
iteration limit reached after 4 steps: root 1.4375, width 0.125
```

## Callback wrapper

`diana_bisection(f, ctx, a, b, tol, max_iter, &root, &iter)` runs the same loop over a callback
`double f(double x, void *ctx)` (`diana_scalar_fn`, `diana/scalar.h`), which must return a finite value. `root`
receives the estimate on `DIANA_OK` and `DIANA_ERR_MAXITER`; `iter` (may be `NULL`) receives the
number of steps. `ctx` passes parameters to the callback without globals. The cube root of 10 as
the root of `x³ − c` with `c` in `ctx`:

```c
#include <stdio.h>

#include <diana/bisection.h>

struct cubic {
  double c;
};

static double cube_minus_c(double x, void *ctx) {
  const struct cubic *p = ctx;
  return x * x * x - p->c;
}

int main(void) {
  struct cubic p = {10.0};
  double root;
  unsigned iter;
  diana_status st =
      diana_bisection(cube_minus_c, &p, 0.0, 10.0, 1e-12, 100u, &root, &iter);
  if (st != DIANA_OK) {
    fprintf(stderr, "bisection: %s after %u steps\n", diana_status_str(st),
            iter);
    return 1;
  }
  printf("cube root of %g: %.15g (%u steps)\n", p.c, root, iter);
  return 0;
}
```

```text
cube root of 10: 2.15443469003191 (44 steps)
```

## Python

`diana.bisection(f, a, b, tol=0.0, max_iter=2100)` returns a root of the callable `f`. The
default `tol = 0` stops at adjacent doubles, within one ulp of the root, and the default
`max_iter` covers the longest possible run (2098 steps), so it is not expected to raise:

```python
>>> import math
>>> import diana
>>> diana.bisection(lambda x: x * x - 2, 0, 2)
1.414213562373095
>>> diana.bisection(lambda x: x * x - 2, 0, 2, tol=1e-6)
1.4142136573791504
>>> diana.bisection(math.cos, 0, 2)
1.5707963267948966
```

`diana.Bisection(a, b, fa, fb, tol=0.0, max_iter=2100)` is the state machine, with the C fields
as read-only attributes, `status`, `step(fx)` (returns the new status) and `result()`:

```python
>>> def f(x):
...     return x * x - 2
>>> s = diana.Bisection(0.0, 2.0, f(0.0), f(2.0), tol=1e-3)
>>> while s.status == diana.CONTINUE:
...     _ = s.step(f(s.x))
>>> s.status == diana.OK, s.iter, s.a, s.b
(True, 11, 1.4140625, 1.4150390625)
>>> s.result()
(1.41455078125, 0.0009765625)
```

`diana.bisection` raises `diana.BracketError` when `f(a)` and `f(b)` have the same sign, and
`diana.MaxIterError` when `max_iter` is reached first; the exception carries the `estimate`, its
`uncertainty` (the bracket width) and `iter`:

```python
>>> diana.bisection(lambda x: x * x + 1, -1, 1)
Traceback (most recent call last):
  ...
diana._diana.BracketError: no sign change in bracket
>>> try:
...     diana.bisection(lambda x: x * x - 2, 0, 2, max_iter=10)
... except diana.MaxIterError as e:
...     print(e.estimate, e.uncertainty, e.iter)
1.4150390625 0.001953125 10
```

## Guarantees

Proved in Lean and Rocq: the bracket always contains a root and halves every step. Proved in
Rocq with Flocq: the binary64 midpoint stays inside the bracket, the computed bracket keeps a
sign change, and a run always terminates. Proved of the C code: VST shows that each function
computes exactly that binary64 model, and Frama-C that it is memory-safe and free of undefined
behaviour. Not proved: a numeric bound on the number of steps; the 2098-step worst case behind the
Python default is measured and pinned by a test. Theorems: `spec/bisection.md`; status: the
[verification report](../verification/report.md).

## Technical notes

[API-007](../../note/api/API-007.md) state invariant,
[API-008](../../note/api/API-008.md) exits in check order,
[API-009](../../note/api/API-009.md) callback wrapper,
[API-023](../../note/api/API-023.md) Python state objects,
[API-024](../../note/api/API-024.md) Python defaults,
[PROOF-001](../../note/proof/PROOF-001.md) what is proved.
