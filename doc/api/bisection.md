# Bisection

Status codes, linking, and the Python conventions shared by every kernel are in the
[API overview](overview.md); the theorems cited below are listed in `spec/bisection.md`.

## C (`diana/bisection.h`)

Reverse-communication form: the kernel uses no function pointer, and the caller evaluates `f` at
`s.x` between calls. Finding `√2` as the root of `x² − 2` in `[0, 2]`:

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

| Field | Meaning |
|---|---|
| `a`, `b` | current bracket, `a <= b` |
| `fa`, `fb` | `f(a)`, `f(b)` |
| `x` | point at which the caller must evaluate `f` next (the midpoint) |
| `tol` | stop when `b - a <= tol`, `tol >= 0` |
| `iter` | steps performed so far |
| `max_iter` | step limit |

Invariant kept by every call (Frama-C WP, BISECTION-C2 to C4 in `spec/bisection.md`): `a <= b`,
`|a|, |b| <= DBL_MAX/2`, `fa` and `fb` finite, `tol >= 0`, and either `fa` and `fb` of strictly
opposite sign or `a == b` with `fa == fb == 0`; whenever the last status was `DIANA_CONTINUE`,
`a < x < b`. The kernel sets `x` to the binary64 midpoint `0.5 * (a + b)`. VST proves that every
function computes its Flocq model: the midpoint helper (BISECTION-C1), `init` and `step` with
every status and every field of the state (BISECTION-C8/C9; the bracket `step` writes is the
layer-B `fstep`, BISECTION-C10), and `diana_bisection_result` (BISECTION-C7); the state `init`
accepts and every state reached through `DIANA_CONTINUE` satisfy the layer-B invariant
(BISECTION-C11/C12). A rejected call leaves the state unchanged (BISECTION-C2/C3, and
BISECTION-C8/C9 for a non-NULL `s`): `init` returning `DIANA_ERR_ARG` or `DIANA_ERR_BRACKET`,
and `step` returning `DIANA_ERR_ARG`, write nothing to `*s`.

- `diana_bisection_init(s, a, b, fa, fb, tol, max_iter)` initialises the state from the bracket
  `[a, b]` and `fa = f(a)`, `fb = f(b)`. Returns `DIANA_CONTINUE` with `s->x` set to the first
  midpoint; `DIANA_OK` if the bracket already satisfies the tolerance, has no representable
  interior point, or `fa == 0` or `fb == 0`;
  `DIANA_ERR_ARG` on NULL, NaN or infinite input, `a > b`, `|a|` or `|b| > DBL_MAX/2`, `tol < 0`, or
  `max_iter == 0`; `DIANA_ERR_BRACKET` if `fa` and `fb` have the same strict sign.
- `diana_bisection_step(s, fx)` consumes `fx = f(s->x)` and halves the bracket: if `fx` and `fa`
  have the same strict sign the root is in `[x, b]`, otherwise in `[a, x]`. Returns `DIANA_CONTINUE`
  with a new `s->x`, `DIANA_OK` on convergence, or `DIANA_ERR_MAXITER`. Convergence also occurs when
  `fx == 0` or the midpoint equals an endpoint (adjacent doubles: no representable interior point
  remains). Returns `DIANA_ERR_ARG` for a NULL state or a non-finite `fx`.
- `diana_bisection_result(s, root, width)` reports the current estimate `root = 0.5 * (a + b)` and
  `width = b - a`. Either output may be NULL; a non-NULL output must not alias the state or the
  other output.

The caller sees every point before `f` is evaluated there, so it can log, evaluate `f` elsewhere,
or stop early. A step that returns `DIANA_ERR_MAXITER` still keeps the bracket (BISECTION-C3), so
`diana_bisection_result` reports the estimate reached so far:

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

`diana/bisection.h`; not verified, see [callback wrapper](overview.md#callback-wrapper).

- `diana_bisection(f, ctx, a, b, tol, max_iter, root, iter)` finds a root of `f` in `[a, b]` by
  bisection, with `f` of type `diana_bisection_fn`. It evaluates `f(a)`, then `f(b)`, then `f` once
  per step. On `DIANA_OK` or `DIANA_ERR_MAXITER`, `*root` holds the current estimate
  `0.5 * (a + b)`; on any other status it is not written. `*iter` (optional) receives the number of
  steps on every return (0 when the arguments or the bracket are rejected). The callback result
  must be finite.

`ctx` passes parameters to the callback without globals. The cube root of 10 as the root of
`x³ − c` with `c` in `ctx`:

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

`diana.Bisection` is the reverse-communication state object and `diana.bisection` the function
taking a Python callable.

`diana.bisection` converts `a` and `b` to `float` before evaluating `f`, so `f(a)` and `f(b)` are
the values at the binary64 endpoints the kernel brackets. `a`, `b`, `tol` and every value `f`
returns must be real numbers (an object with `__float__` or `__index__`; a string is not
converted), `TypeError` otherwise. The default `max_iter` of
`diana.bisection` and `diana.Bisection` is 2100, which covers the worst case of `tol = 0` (2098
steps, for a root at the smallest subnormal in `[-DBL_MAX/2, DBL_MAX/2]`; measured and pinned by a
test — BISECTION-B4 proves termination but not this constant), so with default arguments
`MaxIterError` is not expected. `max_iter` must be an integer that fits a C `unsigned int`
(`OverflowError` otherwise, `ValueError` for 0).

The default `tol = 0` stops at adjacent doubles, so the result is within one ulp of the root:

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

A `diana.Bisection` allocated directly with `__new__` has status `ERR_ARG` until `__init__`
succeeds; `step()` and `result()` raise `RuntimeError` before that. A failed `__init__` leaves the
existing state and status unchanged, so a previously initialized object remains usable.

The state object runs the same loop with the caller in control, as in C; `step` returns the new
status, and the fields of the C state are read-only attributes:

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

`diana.bisection` raises `diana.BracketError` when `f(a)` and `f(b)` do not bracket a root, and
`diana.MaxIterError` when `max_iter` is reached first; the latter carries the attributes
`estimate`, `uncertainty` (the bracket width) and `iter` (also its `args`, so it survives pickling
across a process boundary).

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
